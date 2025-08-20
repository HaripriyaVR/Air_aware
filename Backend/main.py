'''import os
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

SENSOR_IDS = ["lora-v1", "loradev2"]

# ───── Twilio Config ─────
TWILIO_SID        = os.getenv("TWILIO_SID", "")
TWILIO_AUTH_TOKEN = os.getenv("TWILIO_AUTH_TOKEN", "")
TWILIO_VERIFY_SID = os.getenv("TWILIO_VERIFY_SID", "")
twilio_client = TwilioClient(TWILIO_SID, TWILIO_AUTH_TOKEN)

# ───── Boto3 Setup ─────
if not (AWS_ACCESS_KEY and AWS_SECRET_KEY):
    raise RuntimeError("AWS credentials missing in .env")

session = boto3.Session(
    aws_access_key_id=AWS_ACCESS_KEY,
    aws_secret_access_key=AWS_SECRET_KEY,
    region_name=AWS_REGION,
)

s3_client = session.client("s3")
dynamodb = session.resource("dynamodb")
table = dynamodb.Table(DDB_TABLE_NAME)
deserializer = TypeDeserializer()

SENSOR_LOCATIONS = {
    "lora-v1": {"lat": 10.178385739668958, "lon": 76.43052237497399},
    "loradev2": {"lat": 10.17095090340159, "lon": 76.42962876824544},
}

# ───── Flask Setup ─────
app = Flask(__name__)
CORS(app)

# ───── Helpers ─────
def safe_float(val):
    try:
        return float(val)
    except:
        return None

def haversine(lat1, lon1, lat2, lon2):
    R = 6371  # Earth radius in km
    dlat = math.radians(lat2 - lat1)
    dlon = math.radians(lon2 - lon1)
    a = math.sin(dlat / 2)*2 + math.cos(math.radians(lat1)) * math.cos(math.radians(lat2)) * math.sin(dlon / 2)*2
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
    return R * c

# ───────── IDW AQI Calculation ─────────
def idw_aqi(user_lat, user_lon, sensor_data):
    weights = []
    weighted_aqis = []

    print("[IDW] Starting IDW interpolation...")

    for sensor in sensor_data:
        sid = sensor["sensor_id"]
        sensor_lat = SENSOR_LOCATIONS[sid]["lat"]
        sensor_lon = SENSOR_LOCATIONS[sid]["lon"]
        distance = haversine(user_lat, user_lon, sensor_lat, sensor_lon)
        aqi_value = sensor["aqi"]

        print(f"[IDW] Sensor: {sid}, Distance: {distance:.3f} km, AQI: {aqi_value}")

        if distance == 0:
            print(f"[IDW] Exact location match with {sid}. Returning AQI: {aqi_value}")
            return aqi_value

        weight = 1 / (distance ** 2)
        weights.append(weight)
        weighted_aqis.append(aqi_value * weight)
        print(f"[IDW] Weight: {weight:.4f}, Weighted AQI: {aqi_value * weight:.2f}")

    if not weights:
        print("[IDW] No valid weights calculated.")
        return None

    result = round(sum(weighted_aqis) / sum(weights))
    print(f"[IDW] Final IDW AQI: {result}")
    return result


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
            if k not in ("device_id", "received_at", "date", "time")
        }

        computed_aqi = calculate_subindices(readings)

        return {
            "sensor_id": sensor_id,
            "date": date,
            "time":time,
            "readings": readings,
            "aqi": computed_aqi,
            "status": get_aqi_status(computed_aqi) if computed_aqi is not None else "Unknown",
            "source": "dynamodb",
        }

    except Exception as e:
        log.error(f"Error reading from DynamoDB: {e}", exc_info=True)
        return None

# ───── Routes ─────
@app.route("/realtime", methods=["GET"])
def realtime():
    sensor_id = request.args.get("sensor_id")
    if sensor_id:
        data = latest_from_dynamo(sensor_id)
        return jsonify(data) if data else (jsonify(error="not found"), 404)
    return jsonify({
        sid: d for sid in SENSOR_IDS
        if (d := latest_from_dynamo(sid))
    })

@app.route("/send-otp", methods=["POST"])
def send_otp():
    phone = request.get_json(force=True).get("phone")
    if not phone:
        return jsonify(error="phone required"), 400
    try:
        ver = twilio_client.verify.v2.services(TWILIO_VERIFY_SID).verifications.create(
            to=phone, channel="sms"
        )
        return jsonify(status=ver.status)
    except Exception as exc:
        log.error("Twilio send error: %s", exc, exc_info=True)
        return jsonify(error=str(exc)), 500


@app.route("/verify-otp", methods=["POST"])
def verify_otp():
    body = request.get_json(force=True)
    phone, code = body.get("phone"), body.get("code")
    if not phone or not code:
        return jsonify(error="phone and code required"), 400
    try:
        chk = twilio_client.verify.v2.services(TWILIO_VERIFY_SID).verification_checks.create(
            to=phone, code=code
        )
        if chk.status == "approved":
            # Optionally, check if phone exists in DB
            user_token = str(uuid.uuid4())  # Simulated token
            return jsonify(status="approved", token=user_token, phone=phone)
        return jsonify(status=chk.status), 401
    except Exception as exc:
        log.error("Twilio verify error: %s", exc, exc_info=True)
        return jsonify(error=str(exc)), 500

    

@app.route("/forecast", methods=["GET"])
def get_forecast_data():
    device_type = request.args.get('device_type', 'lora-v1')

    if device_type == "lora-v1":
        s3_key = 'data/air_quality/latest_forecast_lora_v1.json'
    elif device_type == "loradev2":
        s3_key = 'data/air_quality/latest_forecast_loradev2.json'
    else:
        s3_key = 'data/air_quality/latest_forecast.json'

    try:
        response = s3_client.get_object(Bucket=S3_BUCKET_NAME, Key=s3_key)
        data = json.loads(response['Body'].read().decode('utf-8'))

        if not isinstance(data, dict) or 'dates' not in data or 'gases' not in data:
            return jsonify({"error": "Invalid data structure"}), 400

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

        return jsonify({
            "forecast": forecast_data,
            "updated_at": updated_at
        }), 200

    except ClientError as e:
        log.error(f"S3 error: {e}")
        return jsonify({"error": "Failed to fetch forecast data"}), 500
    except Exception as e:
        log.error(f"Unexpected error: {e}")
        return jsonify({"error": "Server error"}), 500


@app.route("/user-aqi", methods=["GET"])
def user_aqi():
    try:
        user_lat = float(request.args.get("lat"))
        user_lon = float(request.args.get("lon"))
        print(f"[INPUT] User coordinates: lat={user_lat}, lon={user_lon}")
    except (TypeError, ValueError):
        return jsonify({"error": "Invalid or missing coordinates"}), 400

    nearby_sensors = []
    for sid in SENSOR_IDS:
        sensor_lat = SENSOR_LOCATIONS[sid]["lat"]
        sensor_lon = SENSOR_LOCATIONS[sid]["lon"]
        distance = haversine(user_lat, user_lon, sensor_lat, sensor_lon)
        print(f"[DISTANCE] Sensor: {sid}, Distance: {distance:.3f} km")

        if distance <= 2:
            data = latest_from_dynamo(sid)
            print(f"[SENSOR DATA] {sid} AQI: {data['aqi'] if data else 'No data'}")
            if data and data["aqi"] is not None:
                nearby_sensors.append(data)

    if not nearby_sensors:
        print("[INFO] No sensors found within 2 km.")
        return jsonify({"error": "No nearby sensors within 2 km"}), 404

    aqi = idw_aqi(user_lat, user_lon, nearby_sensors)
    status = get_aqi_status(aqi) if aqi is not None else "Unknown"
    print(f"[RESULT] Interpolated AQI: {aqi}, Status: {status}")

    return jsonify({
        "user_aqi": aqi,
        "status": status,
        "sensor_count": len(nearby_sensors),
        "sources": [s["sensor_id"] for s in nearby_sensors]
    })

from flask import Flask, request, jsonify
import firebase_admin
from firebase_admin import credentials, firestore

app = Flask(__name__)

# Initialize Firebase Admin
cred = credentials.Certificate("airaware-8d0f7-firebase-adminsdk-fbsvc-069f3855d3.json")
firebase_admin.initialize_app(cred)
db = firestore.client()

# ---- Scoring logic ---- #
def calculate_health_score_from_data(data):
    score = 0
    age_scores = {
        "0-12 years": 5,
        "13-18 years": 8,
        "19-40 years": 10,
        "41-60 years": 15,
        "61 years and above": 20
    }
    score += age_scores.get(data.get('age_group', ''), 0)
    score += 2 if data.get('gender') == "Male" else 1
    respiratory_conditions = data.get('respiratory_conditions', [])
    if respiratory_conditions and 'None' not in respiratory_conditions:
        score += len(respiratory_conditions) * 3
    smoking_scores = {
        "Never smoked": 0,
        "Former smoker": 10,
        "Current smoker": 25,
        "Exposed to secondhand smoke": 8
    }
    score += smoking_scores.get(data.get('smoking_history', ''), 0)
    living_environment = data.get('living_environment', [])
    environment_scores = {
        "Urban area": 10,
        "Industrial zone": 15,
        "Rural area": 3,
        "Coastal area": 2
    }
    for env in living_environment:
        score += environment_scores.get(env, 0)
    common_symptoms = data.get('common_symptoms', [])
    symptom_scores = {
        "Frequent coughing": 8,
        "Shortness of breath": 10,
        "Wheezing": 8,
        "Chest tightness": 9
    }
    for symptom in common_symptoms:
        score += symptom_scores.get(symptom, 0)
    occupation_scores = {
        "Construction/Mining": 15,
        "Chemical Industry": 15,
        "Healthcare": 8,
        "Agriculture": 10,
        "Office Environment": 3,
        "Other": 5
    }
    score += occupation_scores.get(data.get('occupational_exposure', ''), 0)
    condition_scores = {
        "Hypertension": 8,
        "Diabetes": 8,
        "Heart Disease": 10,
        "Allergies": 5,
        "Immunocompromised": 12
    }
    medical_history = data.get('medical_history', [])
    for condition in medical_history:
        score += condition_scores.get(condition, 0)
    return score

def get_risk_level(score):
    if score <= 50:
        return 'Low'
    elif score <= 100:
        return 'Moderate'
    elif score <= 150:
        return 'High'
    else:
        return 'Critical'

def get_risk_color(risk_level):
    return {
        'Low': '#10b981',
        'Moderate': '#f59e0b',
        'High': '#ef4444',
        'Critical': '#dc2626'
    }.get(risk_level, '#6b7280')


# ---- Endpoint ---- #
@app.route('/submit-health-assessment', methods=['POST'])
def submit_health():
    try:
        data = request.get_json()

        phone = data.get('phone')
        if not phone:
            return jsonify({'error': 'Missing phone field'}), 400

        score = calculate_health_score_from_data(data)
        risk_level = get_risk_level(score)
        risk_color = get_risk_color(risk_level)

        # Store in Firestore
        health_doc = {
            'phone': phone,
            'score': score,
            'risk_level': risk_level,
            'risk_color': risk_color
        }
        db.collection('health').document(str(phone)).set(health_doc)

        return jsonify({
            'success': True,
            'stored': health_doc
        }), 200

    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500



if __name__ == "__main__":
    app.run(debug=True, host="0.0.0.0", port=5000)'''


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

SENSOR_IDS = ["lora-v1", "loradev2"]

# ───── Twilio Config ─────
DEFAULT_OTP = os.getenv("DEFAULT_OTP", "123456")
TWILIO_SID        = os.getenv("TWILIO_SID", "")
TWILIO_AUTH_TOKEN = os.getenv("TWILIO_AUTH_TOKEN", "")
TWILIO_VERIFY_SID = os.getenv("TWILIO_VERIFY_SID", "")
twilio_client = TwilioClient(TWILIO_SID, TWILIO_AUTH_TOKEN)

# ───── Boto3 Setup ─────
if not (AWS_ACCESS_KEY and AWS_SECRET_KEY):
    raise RuntimeError("AWS credentials missing in .env")

session = boto3.Session(
    aws_access_key_id=AWS_ACCESS_KEY,
    aws_secret_access_key=AWS_SECRET_KEY,
    region_name=AWS_REGION,
)

s3_client = session.client("s3")
dynamodb = session.resource("dynamodb")
table = dynamodb.Table(DDB_TABLE_NAME)
deserializer = TypeDeserializer()

SENSOR_LOCATIONS = {
    "lora-v1": {"lat": 10.178385739668958, "lon": 76.43052237497399},
    "loradev2": {"lat": 10.17095090340159, "lon": 76.42962876824544},
}

# ───── Flask Setup ─────
app = Flask(__name__)
CORS(app)

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
            if k not in ("device_id", "received_at", "date", "time")
        }

        computed_aqi = calculate_subindices(readings)

        return {
            "sensor_id": sensor_id,
            "date": date,
            "time":time,
            "readings": readings,
            "aqi": computed_aqi,
            "status": get_aqi_status(computed_aqi) if computed_aqi is not None else "Unknown",
            "source": "dynamodb",
        }

    except Exception as e:
        log.error(f"Error reading from DynamoDB: {e}", exc_info=True)
        return None
    

@app.route("/aqi", methods=["GET"])
def get_all_aqi():
    """
    Returns AQI values for all sensors in a compact JSON format.
    Example: { "lora-v1": {"aqi": 85, "status": "Moderate"}, "loradev2": {...} }
    """
    data = {}
    for sid in SENSOR_IDS:
        result = latest_from_dynamo(sid)
        if result:
            data[sid] = {
                "aqi": result.get("aqi"),
                "status": result.get("status"),
                "date": result.get("date"),
                "time": result.get("time")
            }
    return jsonify(data)

# ───── Routes ─────
@app.route("/realtime", methods=["GET"])
def realtime():
    sensor_id = request.args.get("sensor_id")
    if sensor_id:
        data = latest_from_dynamo(sensor_id)
        return jsonify(data) if data else (jsonify(error="not found"), 404)
    return jsonify({
        sid: d for sid in SENSOR_IDS
        if (d := latest_from_dynamo(sid))
    })

'''@app.route("/send-otp", methods=["POST"])
def send_otp():
    phone = request.get_json(force=True).get("phone")
    if not phone:
        return jsonify(error="phone required"), 400
    try:
        ver = twilio_client.verify.v2.services(TWILIO_VERIFY_SID).verifications.create(
            to=phone, channel="sms"
        )
        return jsonify(status=ver.status)
    except Exception as exc:
        log.error("Twilio send error: %s", exc, exc_info=True)
        return jsonify(error=str(exc)), 500


@app.route("/verify-otp", methods=["POST"])
def verify_otp():
    body = request.get_json(force=True)
    phone, code = body.get("phone"), body.get("code")
    if not phone or not code:
        return jsonify(error="phone and code required"), 400
    try:
        chk = twilio_client.verify.v2.services(TWILIO_VERIFY_SID).verification_checks.create(
            to=phone, code=code
        )
        if chk.status == "approved":
            # Optionally, check if phone exists in DB
            user_token = str(uuid.uuid4())  # Simulated token
            return jsonify(status="approved", token=user_token, phone=phone)
        return jsonify(status=chk.status), 401
    except Exception as exc:
        log.error("Twilio verify error: %s", exc, exc_info=True)
        return jsonify(error=str(exc)), 500'''




TWILIO_VERIFIED_NUMBERS = [
    "+916282041218"
]

@app.route("/send-otp", methods=["POST"])
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

@app.route("/verify-otp", methods=["POST"])
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



@app.route("/forecast", methods=["GET"])
def get_forecast_data():
    device_type = request.args.get('device_type', 'lora-v1')

    if device_type == "lora-v1":
        s3_key = 'data/air_quality/latest_forecast_lora_v1.json'
    elif device_type == "loradev2":
        s3_key = 'data/air_quality/latest_forecast_loradev2.json'
    else:
        s3_key = 'data/air_quality/latest_forecast.json'

    try:
        response = s3_client.get_object(Bucket=S3_BUCKET_NAME, Key=s3_key)
        data = json.loads(response['Body'].read().decode('utf-8'))

        if not isinstance(data, dict) or 'dates' not in data or 'gases' not in data:
            return jsonify({"error": "Invalid data structure"}), 400

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

        return jsonify({
            "forecast": forecast_data,
            "updated_at": updated_at
        }), 200

    except ClientError as e:
        log.error(f"S3 error: {e}")
        return jsonify({"error": "Failed to fetch forecast data"}), 500
    except Exception as e:
        log.error(f"Unexpected error: {e}")
        return jsonify({"error": "Server error"}), 500


@app.route("/user-aqi", methods=["GET"])
def user_aqi():
    try:
        user_lat = float(request.args.get("lat"))
        user_lon = float(request.args.get("lon"))
        print(f"[INPUT] User coordinates: lat={user_lat}, lon={user_lon}")
    except (TypeError, ValueError):
        return jsonify({"error": "Invalid or missing coordinates"}), 400

    nearby_sensors = []
    for sid in SENSOR_IDS:
        sensor_lat = SENSOR_LOCATIONS[sid]["lat"]
        sensor_lon = SENSOR_LOCATIONS[sid]["lon"]
        distance = haversine(user_lat, user_lon, sensor_lat, sensor_lon)
        print(f"[DISTANCE] Sensor: {sid}, Distance: {distance:.3f} km")

        if distance <= 2:
            data = latest_from_dynamo(sid)
            print(f"[SENSOR DATA] {sid} AQI: {data['aqi'] if data else 'No data'}")
            if data and data["aqi"] is not None:
                nearby_sensors.append(data)

    if not nearby_sensors:
        print("[INFO] No sensors found within 2 km.")
        return jsonify({"error": "No nearby sensors within 2 km"}), 404

    aqi = idw_aqi(user_lat, user_lon, nearby_sensors)
    status = get_aqi_status(aqi) if aqi is not None else "Unknown"
    print(f"[RESULT] Interpolated AQI: {aqi}, Status: {status}")

    return jsonify({
        "user_aqi": aqi,
        "status": status,
        "sensor_count": len(nearby_sensors),
        "sources": [s["sensor_id"] for s in nearby_sensors]
    })



if __name__== "__main__":
    app.run(debug=True, host="0.0.0.0", port=5000)