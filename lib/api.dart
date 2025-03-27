import 'package:flutter/material.dart';

class AppState with ChangeNotifier {
  String _userRole = '';
  String _geminiApiKey = 'AIzaSyCFZGr1ZKfQvL5Sp-XqB9y0K6piOFywoHU';
  final List<Question> _questions = [];
  bool _isFetchingQuestions = false;

  String get userRole => _userRole;
  String get geminiApiKey => _geminiApiKey;
  List<Question> get questions => _questions;
  bool get isFetchingQuestions => _isFetchingQuestions;

  void setUserRole(String role) {
    _userRole = role;
    notifyListeners();
  }

  void setGeminiApiKey(String key) {
    _geminiApiKey = key;
    notifyListeners();
  }

  void setQuestions(List<Question> newQuestions) {
    _questions.clear();
    _questions.addAll(newQuestions);
    notifyListeners();
  }

  void addQuestion(Question question) {
    _questions.add(question);
    notifyListeners();
  }

  void clearQuestions() {
    _questions.clear();
    notifyListeners();
  }

  void setIsFetchingQuestions(bool value) {
    _isFetchingQuestions = value;
    notifyListeners();
  }
}

class Question {
  final String id;
  final String title;
  final String description;
  final String sampleInput;
  final String sampleOutput;
  final String constraints;
  final List<TestCase> testCases;

  Question({
    required this.id,
    required this.title,
    required this.description,
    required this.sampleInput,
    required this.sampleOutput,
    required this.constraints,
    required this.testCases,
  });

  List<TestCase> get visibleTestCases =>
      testCases.where((tc) => !tc.isHidden).toList();
  List<TestCase> get hiddenTestCases =>
      testCases.where((tc) => tc.isHidden).toList();

  factory Question.fromJson(Map<String, dynamic> json) {
    return Question(
      id: json['id'].toString(),
      title: json['title'] as String,
      description: json['description'] as String,
      sampleInput: json['sample_input'] as String,
      sampleOutput: json['sample_output'] as String,
      constraints: json['constraints'] as String,
      testCases: (json['test_cases'] as List<dynamic>?)
              ?.map((tc) => TestCase.fromJson(tc))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'sample_input': sampleInput,
      'sample_output': sampleOutput,
      'constraints': constraints,
      'test_cases': testCases.map((tc) => tc.toJson()).toList(),
    };
  }
}

class TestCase {
  final String input;
  final String expectedOutput;
  final bool isHidden;

  TestCase({
    required this.input,
    required this.expectedOutput,
    this.isHidden = false,
  });

  factory TestCase.fromJson(Map<String, dynamic> json) {
    return TestCase(
      input: json['input'] as String,
      expectedOutput: json['expected_output'] as String,
      isHidden: json['is_hidden'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'input': input,
      'expected_output': expectedOutput,
      'is_hidden': isHidden,
    };
  }
}
