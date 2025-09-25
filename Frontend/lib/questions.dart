import 'package:aqmapp/profile.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'background_design.dart';


class QuestionnairePage extends StatefulWidget {
  final String? phone;
  final bool isEditing;
  const QuestionnairePage({Key? key, required this.phone, this.isEditing = false}) : super(key: key);

  @override
  State<QuestionnairePage> createState() => _QuestionnairePageState();
}

class _QuestionnairePageState extends State<QuestionnairePage> {
  String? AgeGroup;
  String? Gender;
  String? RespiratoryIssue;
  String? SmokingHistory;
  String? Environment;
  String? Occupation;

  List<String> Symptoms = [];
  List<String> symptomOptions = [
    'Frequent Cough',
    'Shortness of Breath',
    'Chest Tightness',
    'Wheezing',
    'Fatigue',
    'Runny Nose'
  ];

  final List<String> AgeOptions = [
    'Below 18', '18-25', '26-35', '36-45', '46-60', 'Above 60'
  ];
  final List<String> GenderOptions = ['Male', 'Female', 'Other'];
  final List<String> yesNo = ['Yes', 'No'];
  final List<String> EnvironmentOptions = [
    'Urban', 'Suburban', 'Rural', 'Industrial Area', 'Near Highways'
  ];
  final List<String> OccupationOptions = [
    'Factory Worker', 'Construction Worker', 'Farmer', 'Office Worker', 'Student', 'Healthcare Worker', 'Other'
  ];

  @override
  void initState() {
    super.initState();
    if (widget.isEditing) {
      fetchExistingData();
    }
  }

  Future<void> fetchExistingData() async {
    final doc = await FirebaseFirestore.instance
        .collection('questionnaire')
        .where('phone', isEqualTo: widget.phone)
        .limit(1)
        .get();

    if (doc.docs.isNotEmpty) {
      final data = doc.docs.first.data();
      setState(() {
        AgeGroup = data['AgeGroup'];
        Gender = data['Gender'];
        RespiratoryIssue = data['RespiratoryIssue'];
        SmokingHistory = data['SmokingHistory'];
        Environment = data['Environment'];
        Occupation = data['Occupation'];
        Symptoms = List<String>.from(data['Symptoms'] ?? []);
      });
    }
  }

  int calculateHealthScore() {
    int score = 0;

    // Age group
    if (AgeGroup == 'Above 60') score += 20;
    else if (AgeGroup == '46-60') score += 15;
    else if (AgeGroup == '36-45') score += 10;
    else if (AgeGroup == '26-35') score += 5;

    // Respiratory issues
    if (RespiratoryIssue == 'Yes') score += 20;

    // Smoking history
    if (SmokingHistory == 'Regular Smoker') score += 20;
    else if (SmokingHistory == 'Occasional Smoker') score += 10;

    // Environment
    if (Environment == 'Industrial Area' || Environment == 'Near Highways') score += 15;
    else if (Environment == 'Urban') score += 10;

    // Symptoms
    score += Symptoms.length * 5;

    // Occupation
    if (Occupation == 'Factory Worker' || Occupation == 'Construction Worker') score += 15;
    else if (Occupation == 'Farmer') score += 10;
    else if (Occupation == 'Healthcare Worker') score += 5;

    return score.clamp(0, 100);
  }

  Map<String, String> getRiskLevel(int score) {
  if (score <= 25) {
    return {'level': 'Low', 'color': '#4CAF50'};        // Green
  } else if (score <= 50) {
    return {'level': 'Moderate', 'color': '#FF9800'};   // Orange
  } else if (score <= 75) {
    return {'level': 'High', 'color': '#F44336'};       // Red
  } else {
    return {'level': 'Critical', 'color': '#B71C1C'};    // Dark Red
  }
}


  Future<void> submit() async {
    if (AgeGroup == null ||
        Gender == null ||
        RespiratoryIssue == null ||
        SmokingHistory == null ||
        Environment == null ||
        Occupation == null ) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❗ Please answer all questions.')),
      );
      return;
    }

    try {
      int score = calculateHealthScore();
      Map<String, String> risk = getRiskLevel(score);

      final query = await FirebaseFirestore.instance
          .collection('questionnaire')
          .where('phone', isEqualTo: widget.phone)
          .limit(1)
          .get();

      final dataToStore = {
        'phone': widget.phone,
        'ageGroup': AgeGroup,
        'gender': Gender,
        'respiratoryIssue': RespiratoryIssue,
        'smokingHistory': SmokingHistory,
        'environment': Environment,
        'occupation': Occupation,
        'symptoms': Symptoms,
        'healthScore': score,
        'riskLevel': risk['level'],
        'riskColor': risk['color'],
        widget.isEditing ? 'updatedAt' : 'submittedAt': Timestamp.now(),
      };

      if (query.docs.isNotEmpty) {
        await query.docs.first.reference.update(dataToStore);
      } else {
        await FirebaseFirestore.instance.collection('questionnaire').add(dataToStore);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(widget.isEditing
                ? '✅ Profile updated successfully!'
                : '✅ Questionnaire submitted successfully!')),
      );

      Future.delayed(const Duration(milliseconds: 800), () {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => ProfilePage(phone: widget.phone,)),
        );
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Error saving responses: $e')),
      );
    }
  }

  Widget buildDropdown({
    required String title,
    required String? value,
    required List<String> options,
    required Function(String?) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 4),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30), // Curve the background border
          ),
          child: Align(
            alignment: Alignment.centerLeft,
            child: SizedBox(
              // width: 320,
              child: DropdownButtonFormField<String>(
                value: value,
                isDense: true,
                items: options.map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
                onChanged: onChanged,
                decoration: InputDecoration(
                  labelText: title,
                  labelStyle: const TextStyle(color: Color.fromARGB(255, 0, 0, 0), fontSize: 18),
                  hintText: 'Select',
                  hintStyle: const TextStyle(color: Colors.grey),
                  border: OutlineInputBorder(
                    
                    borderRadius: BorderRadius.circular(30),
                    borderSide: const BorderSide(color: Colors.green),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: const BorderSide(color: Colors.green),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: const BorderSide(color: Colors.green, width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  fillColor: Colors.white,
                  filled: true,

                ),
                
                icon: const Icon(Icons.arrow_drop_down, color: Colors.green),
                dropdownColor: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

 Widget buildCheckboxList() {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        '6. Common Symptoms',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      ...symptomOptions.map((symptom) {
        return CheckboxListTile(
          title: Text(symptom),
          value: Symptoms.contains(symptom),
          activeColor: Colors.green, // Set checkbox color to green
          onChanged: (bool? value) {
            setState(() {
              if (value == true) {
                Symptoms.add(symptom);
              } else {
                Symptoms.remove(symptom);
              }
            });
          },
        );
      }).toList(),
      const SizedBox(height: 16),
    ],
  );
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent, // Remove background shade
        elevation: 0, // Remove shadow
      ),
      body: Stack(
        children: [
          // const BackgroundDesign(), // Background layer
          SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                const Text(
                  "Health Questionnaire",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(height: 20),
                buildDropdown(
                  title: '1. What is your age group?',
                  value: AgeGroup,
                  options: AgeOptions,
                  onChanged: (val) => setState(() => AgeGroup = val),
                ),
                buildDropdown(
                  title: '2. What is your gender?',
                  value: Gender,
                  options: GenderOptions,
                  onChanged: (val) => setState(() => Gender = val),
                ),
                buildDropdown(
                  title: '3. Do you have any respiratory issues?',
                  value: RespiratoryIssue,
                  options: yesNo,
                  onChanged: (val) => setState(() => RespiratoryIssue = val),
                ),
                buildDropdown(
                  title: '4. Smoking History',
                  value: SmokingHistory,
                  options: ['Non-Smoker', 'Occasional Smoker', 'Regular Smoker'],
                  onChanged: (val) => setState(() => SmokingHistory = val),
                ),
                buildDropdown(
                  title: '5. Living Environment',
                  value: Environment,
                  options: EnvironmentOptions,
                  onChanged: (val) => setState(() => Environment = val),
                ),
                buildCheckboxList(),
                buildDropdown(
                  title: '7. Occupational Exposure',
                  value: Occupation,
                  options: OccupationOptions,
                  onChanged: (val) => setState(() => Occupation = val),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: Text(
                      widget.isEditing ? "Update" : "Submit",
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}