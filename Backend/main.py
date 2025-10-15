import os
import json
import logging
from datetime import datetime
from decimal import Decimal
import math
import uuid
import boto3
from boto3.dynamodb.conditions import Key
from boto3.dynamodb.types import TypeDeserializer
from dotenv import load_dotenv
from flask import Flask, jsonify, request
from flask_cors import CORS
from twilio.rest import Client as TwilioClient
import firebase_admin
from firebase_admin import credentials, firestore
from flask import Blueprint, request, jsonify
from botocore.exceptions import ClientError

# Load .env
load_dotenv()

# ───── Logging ─────
logging.basicConfig(level=logging.INFO)
log = logging.getLogger("backend")

# ───── AWS Config ─────
AWS_REGION     = os.getenv("AWS_REGION", "us-east-1")
AWS_ACCESS_KEY = os.getenv("AWS_ACCESS_KEY_ID")
AWS_SECRET_KEY = os.getenv("AWS_SECRET_ACCESS_KEY")
DDB_TABLE_NAME = os.getenv("DYNAMODB_TABLE", "GasReadings")
S3_BUCKET_NAME = os.getenv("S3_BUCKET_NAME")

SENSOR_IDS = ["lora-v1", "loradev2", "lora-v3"]

# ───── Twilio Config ─────
DEFAULT_OTP = os.getenv("DEFAULT_OTP", "123456")
TWILIO_SID        = os.getenv("TWILIO_SID", "")
TWILIO_AUTH_TOKEN = os.getenv("TWILIO_AUTH_TOKEN", "")
TWILIO_VERIFY_SID = os.getenv("TWILIO_VERIFY_SID", "")
twilio_client = TwilioClient(TWILIO_SID, TWILIO_AUTH_TOKEN)

# ───── Boto3 Setup ─────
# Prefer instance profile / IAM role if explicit credentials are not provided.
if AWS_ACCESS_KEY and AWS_SECRET_KEY:
    session = boto3.Session(
        aws_access_key_id=AWS_ACCESS_KEY,
        aws_secret_access_key=AWS_SECRET_KEY,
        region_name=AWS_REGION,
    )
    log.info("Using explicit AWS credentials from environment variables")
else:
    # Do not raise here; allow boto3 to use instance profile or other configured credentials
    log.warning("AWS credentials not set in environment; falling back to default boto3 session (instance profile or environment).")
    session = boto3.Session(region_name=AWS_REGION)

# Create clients/resources. These calls will use the session's credentials (explicit or instance profile).
s3_client = session.client("s3")
dynamodb = session.resource("dynamodb")
table = dynamodb.Table(DDB_TABLE_NAME)
deserializer = TypeDeserializer()

SENSOR_LOCATIONS = {
    "lora-v1": {"lat": 10.178322, "lon": 76.430891},
    "loradev2": {"lat": 10.18220, "lon": 76.4285},
    "lora-v3": {"lat": 10.17325, "lon": 76.42755},
}

# ───── Flask Setup ─────
app = Flask(__name__)
CORS(app)
api = Blueprint("api", __name__)
# ───── Helpers ─────
def safe_float(val):
    try:
        if val is None:
            return None
        return float(val)
    except (ValueError, TypeError):
        return None

def haversine(lat1, lon1, lat2, lon2):
    """
    Calculate the great circle distance between two points 
    on the earth (specified in decimal degrees)
    """
    try:
        # Convert decimal degrees to radians
        lat1, lat2 = math.radians(float(lat1)), math.radians(float(lat2))
        lon1, lon2 = math.radians(float(lon1)), math.radians(float(lon2))

        # Haversine formula
        dlat = lat2 - lat1
        dlon = lon2 - lon1
        a = math.sin(dlat/2)**2 + math.cos(lat1) * math.cos(lat2) * math.sin(dlon/2)**2
        c = 2 * math.atan2(math.sqrt(max(0, min(1, a))), math.sqrt(max(0, min(1, 1-a))))
        distance = 6371 * c  # 6371 km is Earth's radius

        return round(distance, 3)  # Round to 3 decimal places
    except Exception as e:
        log.error(f"Error in haversine calculation: {e}")
        return float('inf')  # Return infinity for invalid calculations

# ───────── IDW AQI Calculation ─────────
def idw_aqi(user_lat, user_lon, sensor_data):
    try:
        weights = []
        weighted_aqis = []
        
        print("[IDW] Starting IDW interpolation...")
        
        for sensor in sensor_data:
            try:
                sid = sensor["sensor_id"]
                sensor_lat = SENSOR_LOCATIONS[sid]["lat"]
                sensor_lon = SENSOR_LOCATIONS[sid]["lon"]
                distance = haversine(user_lat, user_lon, sensor_lat, sensor_lon)
                aqi_value = sensor["aqi"]

                if distance < 0.001:  # If practically at same location
                    print(f"[IDW] Exact location match with {sid}. Returning AQI: {aqi_value}")
                    return aqi_value
                    
                weight = 1 / (max(distance, 0.001) ** 2)  # Prevent division by zero
                weights.append(weight)
                weighted_aqis.append(aqi_value * weight)
                
                print(f"[IDW] Sensor: {sid}, Distance: {distance:.3f} km, Weight: {weight:.4f}")
                
            except Exception as e:
                print(f"[IDW] Error processing sensor {sid}: {e}")
                continue
                
        if not weights:
            print("[IDW] No valid weights calculated.")
            return None
            
        result = round(sum(weighted_aqis) / sum(weights))
        print(f"[IDW] Final interpolated AQI: {result}")
        return result
        
    except Exception as e:
        print(f"[IDW] Error in calculation: {e}")
        return None

# ───── AQI Calculation ─────
def calculate_subindices(readings):
    def pm25(val): return val*50/30 if val<=30 else 50+(val-30)*50/30 if val<=60 else 100+(val-60)*100/30 if val<=90 else 200+(val-90)*100/30 if val<=120 else 300+(val-120)*100/130 if val<=250 else 400+(val-250)*100/130
    def pm10(val): return val if val<=100 else 100+(val-100)*100/150 if val<=250 else 200+(val-250)*100/100 if val<=350 else 300+(val-350)*100/80 if val<=430 else 400+(val-430)*100/80
    def so2(val): return val*50/40 if val<=40 else 50+(val-40)*50/40 if val<=80 else 100+(val-80)*100/300 if val<=380 else 200+(val-380)*100/420 if val<=800 else 300+(val-800)*100/800 if val<=1600 else 400+(val-1600)*100/800
    def no2(val): return val*50/40 if val<=40 else 50+(val-40)*50/40 if val<=80 else 100+(val-80)*100/100 if val<=180 else 200+(val-180)*100/100 if val<=280 else 300+(val-280)*100/120 if val<=400 else 400+(val-400)*100/120
    def co(val): val *= 0.873; return val*50/1 if val<=1 else 50+(val-1)*50/1 if val<=2 else 100+(val-2)*100/8 if val<=10 else 200+(val-10)*100/7 if val<=17 else 300+(val-17)*100/17 if val<=34 else 400+(val-34)*100/17
    def o3(val): return val if val<=50 else 50+(val-50)*50/50 if val<=100 else 100+(val-100)*100/68 if val<=168 else 200+(val-168)*100/40 if val<=208 else 300+(val-208)*100/540 if val<=748 else 400+(val-748)*100/540
    def nh3(val): return val*50/200 if val<=200 else 50+(val-200)*50/200 if val<=400 else 100+(val-400)*100/400 if val<=800 else 200+(val-800)*100/400 if val<=1200 else 300+(val-1200)*100/600 if val<=1800 else 400+(val-1800)*100/600

    subindices = {
        'pm25': pm25(safe_float(readings.get('pm25', 0))) if readings.get('pm25') else None,
        'pm10': pm10(safe_float(readings.get('pm10', 0))) if readings.get('pm10') else None,
        'so2': so2(safe_float(readings.get('so2', 0))) if readings.get('so2') else None,
        'no2': no2(safe_float(readings.get('no2', 0))) if readings.get('no2') else None,
        'co': co(safe_float(readings.get('co', 0))) if readings.get('co') else None,
        'o3': o3(safe_float(readings.get('o3', 0))) if readings.get('o3') else None,
        'nh3': nh3(safe_float(readings.get('nh3', 0))) if readings.get('nh3') else None,
    }
    valid = [v for v in subindices.values() if v is not None]
    return round(max(valid)) if valid else None

def get_aqi_status(aqi):
    if aqi <= 50: return "Good"
    elif aqi <= 100: return "Satisfactory"
    elif aqi <= 200: return "Moderate"
    elif aqi <= 300: return "Poor"
    elif aqi <= 400: return "Very Poor"
    return "Severe"




# ───── Helper ─────
def latest_from_dynamo(sensor_id):
    try:
        resp = table.query(
            KeyConditionExpression=Key("device_id").eq(sensor_id),
            ScanIndexForward=False,
            Limit=500
        )
        items = resp.get("Items", [])
        if not items:
            log.warning(f"No data found for {sensor_id}")
            return None

        def extract_datetime(item):
            payload = item.get("payload", {})
            date_str = payload.get("date", "").strip()
            time_str = payload.get("time", "").strip()
            try:
                return datetime.strptime(f"{date_str} {time_str}", "%d:%m:%Y %H:%M")
            except Exception:
                return datetime.min

        latest_item = max(items, key=extract_datetime)
        payload = latest_item.get("payload", {})
        date = payload.get("date", "unknown")
        time = payload.get("time", "unknown")

        readings = {
            k: float(v) if isinstance(v, Decimal) else v
            for k, v in payload.items()
            if k not in ("device_id", "received_at", "date", "time", "aqi")
        }

        computed_aqi = calculate_subindices(readings)

        return {
            "sensor_id": sensor_id,
            "date": date,
            "time": time,
            "readings": readings,
            "aqi": computed_aqi,
            "status": get_aqi_status(computed_aqi) if computed_aqi is not None else "Unknown",
            "source": "dynamodb",
        }

    except Exception as e:
        log.error(f"Error reading from DynamoDB: {e}", exc_info=True)
        return None


# ───── API Routes ─────
@api.route("/aqi", methods=["GET"])
def get_all_aqi():
    """
    GET /api/aqi
    Returns compact AQI values for all sensors
    """
    data = {}
    for sid in SENSOR_IDS:
        result = latest_from_dynamo(sid)
        if result:
            data[sid] = {
                "aqi": result.get("aqi"),
                "status": result.get("status"),
                "date": result.get("date"),
                "time": result.get("time"),
            }

    if not data:
        return jsonify({
            "success": False,
            "message": "No AQI data available"
        }), 404

    return jsonify({
        "success": True,
        "data": data
    }), 200


@api.route("/realtime", methods=["GET"])
def get_realtime():
    """
    GET /api/realtime?sensor_id=<id>
    Returns latest readings + AQI for one sensor, 
    or all sensors if no sensor_id is provided.
    """
    sensor_id = request.args.get("sensor_id")
    print(f"📡 Incoming /realtime request, sensor_id={sensor_id}")  # ✅ Debug

    if sensor_id:
        print(f"🔍 Fetching latest data for sensor_id={sensor_id}")
        data = latest_from_dynamo(sensor_id)
        print(f"➡️ Result from Dynamo for {sensor_id}: {data}")  # ✅ Debug

        if data:
            return jsonify({
                "success": True,
                "data": data
            }), 200
        print(f"⚠️ No data found for {sensor_id}")  # ✅ Debug
        return jsonify({
            "success": False,
            "message": f"No data found for sensor_id={sensor_id}"
        }), 404

    # No sensor_id → return all sensors
    all_data = {}
    for sid in SENSOR_IDS:
        print(f"🔍 Fetching data for sensor_id={sid}")  # ✅ Debug
        d = latest_from_dynamo(sid)
        print(f"➡️ Result for {sid}: {d}")  # ✅ Debug

        if d:
            all_data[sid] = d

    if not all_data:
        print("⚠️ No sensor data available in Dynamo!")  # ✅ Debug
        return jsonify({
            "success": False,
            "message": "No sensor data available"
        }), 404

    print(f"✅ Returning realtime data for sensors: {list(all_data.keys())}")  # ✅ Debug
    return jsonify({
        "success": True,
        "data": all_data
    }), 200




TWILIO_VERIFIED_NUMBERS = [
    "+916282041218"
]

@api.route("/send-otp", methods=["POST"])
def send_otp():
    data = request.get_json()
    phone = data.get("phone")

    if not phone:
        return jsonify({"success": False, "message": "Phone number required"}), 400

    if phone in TWILIO_VERIFIED_NUMBERS:
        # Send OTP via Twilio
        twilio_client.verify.v2.services(TWILIO_VERIFY_SID).verifications.create(
            to=phone,
            channel="sms"
        )
        return jsonify({"success": True, "message": "OTP sent via Twilio"})
    else:
        # No OTP sent, just use default
        return jsonify({"success": True, "message": "Using default OTP 123456"})


@api.route("/verify-otp", methods=["POST"])
def verify_otp():
    data = request.get_json()
    phone = data.get("phone")
    otp = data.get("otp")

    if not phone or not otp:
        return jsonify({"success": False, "message": "Phone and OTP required"}), 400

    if phone in TWILIO_VERIFIED_NUMBERS:
        # Verify with Twilio
        verification_check = twilio_client.verify.v2.services(TWILIO_VERIFY_SID).verification_checks.create(
            to=phone,
            code=otp
        )
        if verification_check.status == "approved":
            return jsonify({"success": True, "message": "OTP verified"})
        else:
            return jsonify({"success": False, "message": "Invalid OTP"})
    else:
        # Verify default OTP
        if otp == "123456":
            return jsonify({"success": True, "message": "Default OTP verified"})
        else:
            return jsonify({"success": False, "message": "Invalid default OTP"})



@api.route("/forecast", methods=["GET"])
def get_forecast_data():
    s3_keys = {
        "lora-v1": "data/air_quality/latest_forecast_lora_v1.json",
        "loradev2": "data/air_quality/latest_forecast_loradev2.json",
        "lora-v3": "data/air_quality/latest_forecast_lora-v3.json"
    }

    forecasts = {}

    try:
        for sensor, s3_key in s3_keys.items():
            response = s3_client.get_object(Bucket=S3_BUCKET_NAME, Key=s3_key)
            data = json.loads(response['Body'].read().decode('utf-8'))

            print(f"\n--- Raw S3 data for {sensor} ---")
            print(json.dumps(data, indent=2))
            print("-----------------------------\n")

            if not isinstance(data, dict) or 'dates' not in data or 'gases' not in data:
                forecasts[sensor] = {"error": "Invalid data structure"}
                continue

            dates = data['dates']
            gases = data['gases']
            updated_at = data.get('updated_at')

            forecast_data = []
            gas_mapping = {
                'SO2': 'so2',
                'PM2.5': 'pm25',
                'PM10': 'pm10',
                'NO2': 'no2',
                'NH3': 'nh3',
                'CO': 'co',
                'O3': 'o3'
            }

            for i, date in enumerate(dates):
                try:
                    date_obj = datetime.strptime(date, '%Y-%m-%d')
                    day = date_obj.strftime('%a %d-%m')  # e.g., Fri 18-07
                except:
                    day = f'Day {i+1}'

                entry = {'day': day}

                for gas_name, key in gas_mapping.items():
                    try:
                        values = gases[gas_name]['values']
                        value = float(values[i]) if i < len(values) else 0.0
                        if gas_name == 'CO' and value < 1:
                            value *= 1000  # Convert mg/m³ to µg/m³ if needed
                        entry[f"{key}_max"] = round(value, 2)
                    except Exception as e:
                        log.warning(f"No value for {gas_name} at index {i}: {e}")
                        entry[f"{key}_max"] = 0.0

                forecast_data.append(entry)

            forecasts[sensor] = {
                "forecast": forecast_data,
                "updated_at": updated_at
            }

        return jsonify(forecasts), 200

    except ClientError as e:
        log.error(f"S3 error: {e}")
        return jsonify({"error": "Failed to fetch forecast data"}), 500
    except Exception as e:
        log.error(f"Unexpected error: {e}")
        return jsonify({"error": "Server error"}), 500


@api.route("/user-aqi", methods=["GET"])
def user_aqi():
    try:
        user_lat = float(request.args.get("lat"))
        user_lon = float(request.args.get("lon"))
        print(f"[INPUT] User coordinates: lat={user_lat}, lon={user_lon}")
    except (TypeError, ValueError):
        return jsonify({"error": "Invalid or missing coordinates"}), 400

    sensor_distances = []  # collect all sensors + distances
    for sid in SENSOR_IDS:
        sensor_lat = SENSOR_LOCATIONS[sid]["lat"]
        sensor_lon = SENSOR_LOCATIONS[sid]["lon"]
        distance = haversine(user_lat, user_lon, sensor_lat, sensor_lon)
        data = latest_from_dynamo(sid)
        print(f"[DISTANCE] Sensor: {sid}, Distance: {distance:.3f} km, "
              f"AQI: {data['aqi'] if data else 'No data'}")

        if data and data.get("aqi") is not None:
            sensor_distances.append({
                "sensor_id": sid,
                "lat": sensor_lat,
                "lon": sensor_lon,
                "aqi": data["aqi"],
                "distance": distance
            })

    if not sensor_distances:
        print("[INFO] No sensors with AQI data at all.")
        return jsonify({"error": "No sensor data available"}), 404

    # Sort by distance
    sensor_distances.sort(key=lambda x: x["distance"])

    # Option A: use top 3 nearest sensors
    nearest_sensors = sensor_distances[:3]

    # Option B: or use all sensors but weighted by distance (IDW handles that)
    # nearest_sensors = sensor_distances

    aqi = idw_aqi(user_lat, user_lon, nearest_sensors)
    status = get_aqi_status(aqi) if aqi is not None else "Unknown"

    # 🔹 Get nearest sensor info
    nearest_sensor = min(sensor_distances, key=lambda x: x["distance"])

    print(f"[RESULT] Interpolated AQI: {aqi}, Status: {status}, "
          f"Nearest Sensor: {nearest_sensor['sensor_id']} ({nearest_sensor['distance']:.3f} km)")

    return jsonify({
        "user_aqi": aqi,
        "status": status,
        "sensor_count": len(nearest_sensors),
        "closest_sensor": {
            "sensor_id": nearest_sensor["sensor_id"],
            "distance_km": round(nearest_sensor["distance"], 3)
        },
        "sources": [s["sensor_id"] for s in nearest_sensors]
    })



if __name__== "__main__":
    # Register API blueprint with /api prefix
    app.register_blueprint(api, url_prefix="/api")

    port = int(os.environ.get("PORT", 8080))
    app.run(debug=True, host="0.0.0.0", port=port)