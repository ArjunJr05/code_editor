import 'package:codeed/login2.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_code_editor/flutter_code_editor.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/atom-one-dark.dart';
import 'package:highlight/languages/python.dart';
import 'package:highlight/languages/dart.dart';
import 'package:highlight/languages/java.dart';
import 'package:highlight/languages/javascript.dart';
import 'package:highlight/languages/cpp.dart';
import 'package:codeed/api.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';

import 'package:wakelock_plus/wakelock_plus.dart';

class StudentScreen extends StatefulWidget {
  final String registerNumber;
  final String name;

  const StudentScreen(
      {super.key, required this.registerNumber, required this.name});

  @override
  State<StudentScreen> createState() => _StudentScreenState();
}

class _StudentScreenState extends State<StudentScreen>
    with WidgetsBindingObserver {
  int _selectedQuestionIndex = 0;
  late CodeController _codeController;
  bool _isLoading = false;
  bool _isFetchingQuestions = true;
  String _result = '';
  List<String> _testResults = [];
  String _currentLanguage = 'python';

  // Panel sizing
  double _codeEditorHeight = 300;
  double _questionPanelHeight = 300;

  // Colors
  final Color primaryColor = const Color(0xFF00158F);
  final Color backgroundColor = Colors.white;
  final Color codeBackgroundColor = const Color(0xFF282C34);
  final Color resultBackgroundColor = const Color(0xFFF0F4FF);

  // Test monitoring
  int _malpracticeCount = 0;
  bool _testFinished = false;
  int _score = 0;
  int _totalQuestions = 0;
  DateTime? _lastInteractionTime;
  bool _isTestActive = false;
  Timer? _inactivityTimer;
  List<bool> _answeredQuestions = [];
  int _currentCredit = 0;
  List<String> _questionCodes = []; // Stores code for each question

  // Timer variables
  // Timer variables
  Duration _remainingTime = const Duration(minutes: 90); // Already correct
  Timer? _countdownTimer;
  bool _timeExpired = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _codeController = CodeController(text: '');
    _fetchQuestions();
    _fetchCurrentCredit();
    WakelockPlus.enable();
    _startCountdownTimer();

    // Add listener for app state changes
    SystemChannels.lifecycle.setMessageHandler((msg) async {
      if (!_isTestActive) return null;

      debugPrint('System lifecycle change: $msg');

      if (msg == AppLifecycleState.paused.toString() ||
          msg == AppLifecycleState.inactive.toString()) {
        _handleMalpractice();
      }
      return null;
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _inactivityTimer?.cancel();
    _countdownTimer?.cancel();
    WakelockPlus.disable();
    super.dispose();
  }

  Future<void> _fetchCurrentCredit() async {
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('students')
          .select('credit')
          .eq('register_number', widget.registerNumber)
          .single();

      setState(() {
        _currentCredit = response['credit'] as int? ?? 0;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error fetching credit: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _updateStudentCredit(int newCredit) async {
    try {
      final supabase = Supabase.instance.client;
      await supabase.from('students').update({'credit': newCredit}).eq(
          'register_number', widget.registerNumber);
      setState(() {
        _currentCredit = newCredit;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating credit: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _saveTestResults() async {
    try {
      final supabase = Supabase.instance.client;
      final appState = Provider.of<AppState>(context, listen: false);

      // Prepare code submissions for each question
      final codeSubmissions = <String, String>{};
      for (int i = 0; i < appState.questions.length; i++) {
        final questionId = appState.questions[i].id;
        final code = _questionCodes.length > i ? _questionCodes[i] : '';
        codeSubmissions[questionId] = code;
      }

      // Prepare test data including question details
      final testData = {
        'questions': appState.questions.asMap().entries.map((entry) {
          final index = entry.key;
          final question = entry.value;
          return {
            'question_id': question.id,
            'title': question.title,
            'answered': _answeredQuestions.length > index
                ? _answeredQuestions[index]
                : false,
            'test_cases': question.testCases
                .map((tc) => {
                      'input': tc.input,
                      'expected_output': tc.expectedOutput,
                      'is_hidden': tc.isHidden,
                    })
                .toList(),
          };
        }).toList(),
        'timestamp': DateTime.now().toIso8601String(),
        'malpractice': _malpracticeCount > 0,
        'malpractice_count': _malpracticeCount,
        'time_expired': _timeExpired,
      };

      // Calculate duration in minutes (30 - remaining minutes)
      final durationMinutes = 90 - _remainingTime.inMinutes;

      // Insert into the results table
      await supabase.from('results').insert({
        'register_number': widget.registerNumber,
        'name': widget.name,
        'marks': _score,
        'total_marks': _totalQuestions,
        'malpractice_count': _malpracticeCount,
        'is_malpractice': _malpracticeCount > 0,
        'duration_minutes': 90 - _remainingTime.inMinutes,
        'language_used': _currentLanguage,
        'grading_notes': '', // Can be filled by instructor later
        'is_submitted': true,
        'time_expired': _timeExpired,
        'test_data': {
          'questions': appState.questions.asMap().entries.map((entry) {
            final index = entry.key;
            final question = entry.value;
            return {
              'question_id': question.id,
              'title': question.title,
              'answered': _answeredQuestions.length > index
                  ? _answeredQuestions[index]
                  : false,
              'test_cases': question.testCases
                  .map((tc) => {
                        'input': tc.input,
                        'expected_output': tc.expectedOutput,
                        'is_hidden': tc.isHidden,
                      })
                  .toList(),
            };
          }).toList(),
          'timestamp': DateTime.now().toIso8601String(),
          'malpractice': _malpracticeCount > 0,
          'malpractice_count': _malpracticeCount,
        },
        'code_submissions': Map.fromEntries(
          appState.questions.asMap().entries.map((entry) {
            final index = entry.key;
            return MapEntry(entry.value.id,
                _questionCodes.length > index ? _questionCodes[index] : '');
          }),
        ),
      });

      // Update student credit only if no malpractice
      if (_malpracticeCount == 0) {
        await _updateStudentCredit(_currentCredit + _score);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving results: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_isTestActive) return;

    if (state == AppLifecycleState.paused) {
      _handleMalpractice();
    }
  }

  void _handleMalpractice() {
    if (!_isTestActive) return;

    setState(() {
      _malpracticeCount++;
    });

    if (_malpracticeCount == 1) {
      // Show warning dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Warning'),
          content: const Text(
              'Please do not switch apps or tabs during the test. '
              'This is your first warning. Next time your test will be submitted automatically.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _recordInteraction(); // Reset interaction timer
              },
              child: const Text('OK'),
            ),
          ],
        ),
      ).then((_) {
        _recordInteraction(); // Ensure interaction is recorded after dialog dismiss
      });
    } else if (_malpracticeCount >= 3) {
      // Force submit the test
      _submitTestWithMalpractice();
    }
  }

  void _startTest() {
    setState(() {
      _isTestActive = true;
      _lastInteractionTime = DateTime.now();
      _answeredQuestions = List.filled(_totalQuestions, false);
      _questionCodes = List.filled(_totalQuestions, '');
      _startInactivityTimer();
    });
    WakelockPlus.enable();
  }

  void _submitTestWithMalpractice() async {
    // Show immediate feedback
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Test submitted due to malpractice!'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 5),
        ),
      );
    }

    // Force submit
    await _saveTestResults();

    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => Scaffold(
            backgroundColor: Colors.white,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.warning, size: 60, color: Colors.red),
                  const SizedBox(height: 20),
                  Text(
                    'Test Submitted Due to Malpractice',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.red[800],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Your score: $_score/$_totalQuestions',
                    style: const TextStyle(fontSize: 18),
                  ),
                  const SizedBox(height: 30),
                  ElevatedButton(
                    onPressed: () => _navigateToLogin(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Return to Login'),
                  ),
                ],
              ),
            ),
          ),
        ),
        (Route<dynamic> route) => false,
      );
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "$twoDigitMinutes:$twoDigitSeconds";
  }

  void _submitTest() async {
    setState(() {
      _testFinished = true;
      _isTestActive = false;
      _inactivityTimer?.cancel();
      _countdownTimer?.cancel();
      _calculateScore();
    });
    WakelockPlus.disable();

    // Save the current code for the active question before submitting
    if (_selectedQuestionIndex < _questionCodes.length) {
      _questionCodes[_selectedQuestionIndex] = _codeController.text;
    }

    // Save test results to Supabase
    await _saveTestResults();

    if (mounted && !_timeExpired) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Test submitted! Your score: $_score/$_totalQuestions'),
          backgroundColor: Colors.blue,
        ),
      );
    }
  }

  void _startCountdownTimer() {
    _isTestActive = true;
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingTime.inSeconds == 0) {
        _countdownTimer?.cancel();
        _timeExpired = true;
        _submitTest();
      } else {
        setState(() {
          _remainingTime = _remainingTime - const Duration(seconds: 1);
        });
      }
    });
  }

  void _startInactivityTimer() {
    _inactivityTimer?.cancel();
    _inactivityTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_lastInteractionTime == null || !_isTestActive) return;

      final inactiveDuration = DateTime.now().difference(_lastInteractionTime!);
      if (inactiveDuration.inSeconds > 90) {
        _handleMalpractice();
      }
    });
  }

  void _recordInteraction() {
    if (!_isTestActive) return;
    setState(() {
      _lastInteractionTime = DateTime.now();
    });
  }

  void _calculateScore() {
    _score = _answeredQuestions.where((answered) => answered).length;
  }

  Future<void> _fetchQuestions() async {
    final appState = Provider.of<AppState>(context, listen: false);

    try {
      setState(() {
        _isFetchingQuestions = true;
      });

      final supabase = Supabase.instance.client;
      final questionsResponse = await supabase.from('questions').select('*');
      final testCasesResponse = await supabase.from('test_cases').select('*');

      final List<Question> questions = [];

      for (final questionData in questionsResponse) {
        final questionTestCases = testCasesResponse
            .where((tc) => tc['question_id'] == questionData['id'])
            .map((tc) => TestCase(
                  input: tc['input'] as String,
                  expectedOutput: tc['expected_output'] as String,
                  isHidden: tc['is_hidden'] as bool? ?? false,
                ))
            .toList();

        questions.add(Question(
          id: questionData['id'].toString(),
          title: questionData['title'] as String,
          description: questionData['description'] as String,
          sampleInput: questionData['sample_input'] as String,
          sampleOutput: questionData['sample_output'] as String,
          constraints: questionData['constraints'] as String,
          testCases: questionTestCases,
        ));
      }

      appState.setQuestions(questions);
      setState(() {
        _totalQuestions = questions.length;
        // Initialize answered questions and codes
        _answeredQuestions = List.filled(questions.length, false);
        _questionCodes = List.filled(questions.length, '');
        // Reset selected index if out of bounds
        if (_selectedQuestionIndex >= questions.length) {
          _selectedQuestionIndex = 0;
        }
      });
    } catch (e) {
      // ... existing error handling
    } finally {
      setState(() {
        _isFetchingQuestions = false;
      });
    }
  }

  void _setLanguage(String language) {
    setState(() {
      _currentLanguage = language;
      switch (language) {
        case 'python':
          _codeController.language = python;
          break;
        case 'dart':
          _codeController.language = dart;
          break;
        case 'java':
          _codeController.language = java;
          break;
        case 'javascript':
          _codeController.language = javascript;
          break;
        case 'cpp':
          _codeController.language = cpp;
          break;
        default:
          _codeController.language = python;
      }
    });
  }

  void _navigateToLogin(BuildContext context) {
    WakelockPlus.disable();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => LoginPage()),
      (Route<dynamic> route) => false,
    );
  }

  Future<void> _runCode() async {
    if (!_isTestActive) {
      _startTest();
    }

    // Save the current code for this question
    if (_selectedQuestionIndex < _questionCodes.length) {
      _questionCodes[_selectedQuestionIndex] = _codeController.text;
    }

    final appState = Provider.of<AppState>(context, listen: false);
    if (appState.questions.isEmpty ||
        _selectedQuestionIndex >= appState.questions.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No question selected')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _result = '';
      _testResults = [];
    });

    try {
      final question = appState.questions[_selectedQuestionIndex];
      final allTestCases = question.testCases;

      String prompt = """
Analyze the following $_currentLanguage code for syntax errors and logical errors.
If there are no errors, execute the code and provide the output for each test case.

Code:
${_codeController.text}

First, check for syntax errors. If found, return them in this format:
SYNTAX ERROR:
<line number>: <error description>

If no syntax errors, check for runtime errors during test case execution.
For runtime errors, return:
RUNTIME ERROR:
<error description>

If no errors, execute the code with these test cases and provide outputs:
${allTestCases.asMap().entries.map((entry) {
        final idx = entry.key + 1;
        final tc = entry.value;
        return "Test Case $idx:\nInput: ${tc.input}\nExpected Output: ${tc.expectedOutput}";
      }).join("\n\n")}

Provide output in this format:
Test Case 1: <output>
Test Case 2: <output>
...
""";

      final response = await http.post(
        Uri.parse(
            'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-pro-latest:generateContent?key=${appState.geminiApiKey}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "contents": [
            {
              "parts": [
                {"text": prompt}
              ]
            }
          ]
        }),
      );

      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);
        final generatedText =
            responseBody['candidates'][0]['content']['parts'][0]['text'];

        if (generatedText.contains('SYNTAX ERROR:') ||
            generatedText.contains('RUNTIME ERROR:')) {
          setState(() {
            _result = generatedText;
            _testResults = ['❌ Error in code execution'];
          });
          return;
        }

        List<String> testResults = [];
        int hiddenPassed = 0;
        int hiddenFailed = 0;

        // Process test cases
        for (int i = 0; i < allTestCases.length; i++) {
          final testCase = allTestCases[i];
          final expectedPattern = RegExp('Test Case ${i + 1}: (.*)');
          final match = expectedPattern.firstMatch(generatedText);

          if (match != null) {
            final actualOutput = match.group(1)!.trim();
            final isCorrect = actualOutput == testCase.expectedOutput;

            if (!testCase.isHidden) {
              testResults.add(
                  'Test Case ${i + 1}: ${isCorrect ? '✅ Correct' : '❌ Wrong'}\n'
                  'Input: ${testCase.input}\n'
                  'Expected: ${testCase.expectedOutput}\n'
                  'Actual: $actualOutput\n');
            } else if (isCorrect) {
              hiddenPassed++;
            } else {
              hiddenFailed++;
            }
          } else if (!testCase.isHidden) {
            testResults.add('Test Case ${i + 1}: ❌ No output received');
          } else {
            hiddenFailed++;
          }
        }

        // Add hidden test cases summary
        if (allTestCases.any((tc) => tc.isHidden)) {
          testResults.add(
              '\nHidden Test Cases: $hiddenPassed passed, $hiddenFailed failed');
        }

        // Check if all test cases passed
        final allPassed = hiddenFailed == 0 &&
            testResults
                .where((r) => r.startsWith('Test Case'))
                .every((r) => r.contains('✅'));

        setState(() {
          _result = generatedText;
          _testResults = testResults;
          _answeredQuestions[_selectedQuestionIndex] = allPassed;
        });
      } else {
        setState(() {
          _result = 'Error: ${response.statusCode}\n${response.body}';
          _testResults = ['❌ Failed to execute code'];
        });
      }
    } catch (e) {
      setState(() {
        _result = 'Error: $e';
        _testResults = ['❌ Exception occurred during execution'];
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 600;

    if (_isFetchingQuestions) {
      return Scaffold(
        backgroundColor: backgroundColor,
        appBar: AppBar(
          backgroundColor: primaryColor,
          elevation: 0,
          title: const Text(
            'Student Panel',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_testFinished) {
      return Scaffold(
        backgroundColor: backgroundColor,
        appBar: AppBar(
          backgroundColor: primaryColor,
          elevation: 0,
          title: const Text(
            'Test Results',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _timeExpired ? 'Time Expired!' : 'Test Completed',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Your Score: $_score/$_totalQuestions',
                style: const TextStyle(
                  fontSize: 20,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Time Taken: ${90 - _remainingTime.inMinutes} minutes',
                style: const TextStyle(
                  fontSize: 20,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Your Credit: $_currentCredit',
                style: const TextStyle(
                  fontSize: 20,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => _navigateToLogin(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                ),
                child: const Text('Return to Login'),
              ),
            ],
          ),
        ),
      );
    }

    List<Widget> actions = [
      // In your actions list, update the timer display:
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _remainingTime.inMinutes < 5
                ? Colors.red.withOpacity(0.8)
                : Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            _formatDuration(_remainingTime),
            style: TextStyle(
              color: _remainingTime.inMinutes < 5 ? Colors.white : Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
      ),
      IconButton(
        icon: const Icon(Icons.refresh),
        onPressed: _fetchQuestions,
        tooltip: 'Refresh Questions',
      ),
      IconButton(
        icon: const Icon(Icons.logout),
        onPressed: () => _navigateToLogin(context),
        tooltip: 'Logout',
      ),
      IconButton(
        icon: const Icon(Icons.assignment_turned_in),
        onPressed: _submitTest,
        tooltip: 'Submit Test',
      ),
    ];

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: primaryColor,
        elevation: 0,
        title: const Text(
          'Student Panel',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: actions,
      ),
      body: appState.questions.isEmpty
          ? _buildEmptyState()
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  _buildQuestionSelector(appState),
                  const SizedBox(height: 16),
                  Expanded(
                    child: isSmallScreen
                        ? _buildVerticalLayout()
                        : _buildHorizontalLayout(),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.assignment_late_outlined,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          const Text(
            'No questions available',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Please wait for the instructor to add questions',
            style: TextStyle(
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionSelector(AppState appState) {
    if (appState.questions.isEmpty) {
      return Container(); // Return empty container if no questions
    }
    return Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(children: [
          Icon(Icons.assignment, color: primaryColor),
          const SizedBox(width: 12),
          const Text(
            'Select Question:',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
              child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              isExpanded: true,
              value: _selectedQuestionIndex.clamp(
                  0, appState.questions.length - 1),
              items: List.generate(appState.questions.length, (index) {
                return DropdownMenuItem<int>(
                  value: index,
                  child: Row(
                    children: [
                      if (_answeredQuestions.length > index &&
                          _answeredQuestions[index])
                        const Icon(Icons.check_circle,
                            color: Colors.green, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        appState.questions[index].title,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                );
              }),
              onChanged: (value) {
                if (value != null && value < appState.questions.length) {
                  setState(() {
                    _selectedQuestionIndex = value;
                    _result = '';
                    _testResults = [];
                    _recordInteraction();
                  });
                }
              },
            ),
          ))
        ]));
  }

  Widget _buildVerticalLayout() {
    return Column(
      children: [
        SizedBox(
          height: _questionPanelHeight,
          child: Listener(
            onPointerDown: (_) => _recordInteraction(),
            child: _buildQuestionCard(),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: _codeEditorHeight,
          child: Listener(
            onPointerDown: (_) => _recordInteraction(),
            child: _buildCodeEditor(),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _buildResultsArea(),
        ),
      ],
    );
  }

  Widget _buildHorizontalLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: MediaQuery.of(context).size.width * 0.35,
          child: Listener(
            onPointerDown: (_) => _recordInteraction(),
            child: _buildQuestionCard(),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            children: [
              SizedBox(
                height: _codeEditorHeight,
                child: Listener(
                  onPointerDown: (_) => _recordInteraction(),
                  child: _buildCodeEditor(),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: _buildResultsArea(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuestionCard() {
    final appState = Provider.of<AppState>(context);
    if (appState.questions.isEmpty ||
        _selectedQuestionIndex >= appState.questions.length) {
      return const Center(child: Text('No question available'));
    }

    final question = appState.questions[_selectedQuestionIndex];

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.quiz,
                    color: primaryColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    question.title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildQuestionSection('Description', question.description),
                    const SizedBox(height: 16),
                    _buildSampleSection(question),
                    const SizedBox(height: 16),
                    _buildConstraintsSection(question),
                    const SizedBox(height: 16),
                    _buildTestCasesPreview(question),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionSection(String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$title:',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 8),
        Text(content),
      ],
    );
  }

  Widget _buildSampleSection(Question question) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Sample:',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Input:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                question.sampleInput,
                style: const TextStyle(fontFamily: 'monospace'),
              ),
              const SizedBox(height: 12),
              Text(
                'Output:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                question.sampleOutput,
                style: const TextStyle(fontFamily: 'monospace'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildConstraintsSection(Question question) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Constraints:',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.orange.shade200),
          ),
          child: Text(
            question.constraints,
            style: TextStyle(
              color: Colors.orange.shade800,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTestCasesPreview(Question question) {
    final visibleTestCases =
        question.testCases.where((tc) => !tc.isHidden).toList();

    if (visibleTestCases.isEmpty) {
      return const SizedBox();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Test Cases:',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade200),
            borderRadius: BorderRadius.circular(8),
          ),
          child: ListView.separated(
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            itemCount: visibleTestCases.length,
            separatorBuilder: (context, index) => Divider(
              height: 1,
              color: Colors.grey.shade200,
            ),
            itemBuilder: (context, index) {
              final testCase = visibleTestCases[index];
              return Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Test Case ${index + 1}:',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text('Input: ${testCase.input}'),
                    Text('Expected Output: ${testCase.expectedOutput}'),
                  ],
                ),
              );
            },
          ),
        ),
        if (question.testCases.any((tc) => tc.isHidden))
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(
              '${question.testCases.where((tc) => tc.isHidden).length} hidden test cases not shown',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCodeEditor() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.code,
                    color: primaryColor,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Code Editor',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 16),
                DropdownButton<String>(
                  value: _currentLanguage,
                  items: [
                    DropdownMenuItem(value: 'python', child: Text('Python')),
                    DropdownMenuItem(
                        value: 'javascript', child: Text('JavaScript')),
                    DropdownMenuItem(value: 'java', child: Text('Java')),
                    DropdownMenuItem(value: 'dart', child: Text('Dart')),
                    DropdownMenuItem(value: 'cpp', child: Text('C++')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      _setLanguage(value);
                      _recordInteraction();
                    }
                  },
                  underline: Container(),
                  icon: Icon(Icons.arrow_drop_down, color: primaryColor),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  icon: _isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.play_arrow),
                  label: Text(_isLoading ? 'Running...' : 'Run Code'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: _isLoading ? null : _runCode,
                ),
              ],
            ),
            const Divider(height: 24),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: codeBackgroundColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade800),
                ),
                child: CodeTheme(
                  data: CodeThemeData(styles: atomOneDarkTheme),
                  child: CodeField(
                    controller: _codeController,
                    textStyle: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 14,
                    ),
                    gutterStyle: const GutterStyle(
                      textStyle: TextStyle(
                        color: Colors.grey,
                        fontSize: 14,
                      ),
                      width: 40,
                      margin: 10,
                    ),
                    expands: true,
                    minLines: null,
                    maxLines: null,
                  ),
                ),
              ),
            ),
            Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: codeBackgroundColor.withOpacity(0.7),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(8),
                  bottomRight: Radius.circular(8),
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.format_indent_increase,
                        color: Colors.white70),
                    tooltip: 'Indent',
                    onPressed: () {
                      final currentPosition = _codeController.selection.start;
                      final selectedText = _codeController.text.substring(
                        _codeController.selection.start,
                        _codeController.selection.end,
                      );

                      if (selectedText.isNotEmpty) {
                        final lines = selectedText.split('\n');
                        final indentedText =
                            lines.map((line) => '  $line').join('\n');
                        _codeController.text =
                            _codeController.text.replaceRange(
                          _codeController.selection.start,
                          _codeController.selection.end,
                          indentedText,
                        );
                      } else {
                        _codeController.text =
                            _codeController.text.replaceRange(
                          currentPosition,
                          currentPosition,
                          '  ',
                        );
                        _codeController.selection = TextSelection.collapsed(
                          offset: currentPosition + 2,
                        );
                      }
                      _recordInteraction();
                    },
                  ),
                  IconButton(
                    icon: Icon(Icons.format_indent_decrease,
                        color: Colors.white70),
                    tooltip: 'Outdent',
                    onPressed: () {
                      if (_codeController.selection.start !=
                          _codeController.selection.end) {
                        final selectedText = _codeController.text.substring(
                          _codeController.selection.start,
                          _codeController.selection.end,
                        );

                        final lines = selectedText.split('\n');
                        final outdentedLines = lines.map((line) {
                          if (line.startsWith('  ')) {
                            return line.substring(2);
                          } else if (line.startsWith(' ')) {
                            return line.substring(1);
                          }
                          return line;
                        }).join('\n');

                        _codeController.text =
                            _codeController.text.replaceRange(
                          _codeController.selection.start,
                          _codeController.selection.end,
                          outdentedLines,
                        );
                      }
                      _recordInteraction();
                    },
                  ),
                  const VerticalDivider(color: Colors.white24),
                  IconButton(
                    icon: Icon(Icons.content_copy, color: Colors.white70),
                    tooltip: 'Copy',
                    onPressed: () {
                      final textToCopy = _codeController.selection
                          .textInside(_codeController.text);
                      if (textToCopy.isNotEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content:
                                  Text('Selected text copied to clipboard')),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('All code copied to clipboard')),
                        );
                      }
                      _recordInteraction();
                    },
                  ),
                  IconButton(
                    icon: Icon(Icons.format_clear, color: Colors.white70),
                    tooltip: 'Clear All',
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Clear Code'),
                          content: const Text(
                              'Are you sure you want to clear all code?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () {
                                _codeController.text = '';
                                Navigator.pop(context);
                                _recordInteraction();
                              },
                              child: const Text('Clear'),
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.red,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const Spacer(),
                  Text(
                    'Ln ${_codeController.selection.base.offset}, Col ${_codeController.selection.extent.offset}',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsArea() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.analytics,
                    color: primaryColor,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Test Results',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (_testResults.isNotEmpty)
                  TextButton.icon(
                    icon: const Icon(Icons.share),
                    label: const Text('Share Results'),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Share Results'),
                          content: const Text(
                              'Results can be shared with your instructor for feedback.'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content:
                                        Text('Results shared with instructor'),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                                _recordInteraction();
                              },
                              child: const Text('Share'),
                              style: TextButton.styleFrom(
                                foregroundColor: primaryColor,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
              ],
            ),
            const Divider(height: 24),
            Expanded(
              child: _testResults.isEmpty && _result.isEmpty
                  ? _buildEmptyResultsPlaceholder()
                  : _buildResultsContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyResultsPlaceholder() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.pending_actions,
            size: 48,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Run your code to see results',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsContent() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: resultBackgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_testResults.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _result.contains('ERROR:')
                    ? Colors.red.withOpacity(0.1)
                    : primaryColor.withOpacity(0.05),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(8),
                  topRight: Radius.circular(8),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _result.contains('ERROR:')
                        ? Icons.error
                        : _testResults.every((r) => !r.contains('❌'))
                            ? Icons.check_circle
                            : Icons.info,
                    color: _result.contains('ERROR:')
                        ? Colors.red
                        : _testResults.every((r) => !r.contains('❌'))
                            ? Colors.green
                            : Colors.orange,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _result.contains('SYNTAX ERROR:')
                        ? 'Syntax Error Found'
                        : _result.contains('RUNTIME ERROR:')
                            ? 'Runtime Error Found'
                            : _testResults.every((r) => !r.contains('❌'))
                                ? 'All visible tests passed!'
                                : 'Some tests failed',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _result.contains('ERROR:')
                          ? Colors.red
                          : _testResults.every((r) => !r.contains('❌'))
                              ? Colors.green
                              : Colors.orange,
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: _result.contains('ERROR:')
                  ? _buildErrorDisplay()
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_testResults.isNotEmpty) ...[
                          for (var result in _testResults)
                            _buildTestResultItem(result),
                        ],
                        if (_result.isNotEmpty && _testResults.isEmpty)
                          SelectableText(
                            _result,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 14,
                            ),
                          ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorDisplay() {
    String errorMessage = _result;
    if (_result.contains('SYNTAX ERROR:')) {
      errorMessage = _result.replaceAll('SYNTAX ERROR:', '🚨 Syntax Error:');
    } else if (_result.contains('RUNTIME ERROR:')) {
      errorMessage = _result.replaceAll('RUNTIME ERROR:', '⚠️ Runtime Error:');
    } else if (_result.contains('LANGUAGE MISMATCH ERROR:')) {
      errorMessage = _result.replaceAll(
          'LANGUAGE MISMATCH ERROR:', '⚠️ Language Mismatch:');
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _result.contains('LANGUAGE MISMATCH ERROR:')
                ? 'Language Mismatch Detected'
                : 'Code Error Detected',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.red,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          SelectableText(
            errorMessage,
            style: const TextStyle(
              fontFamily: 'monospace',
              color: Colors.red,
            ),
          ),
          const SizedBox(height: 16),
          if (_result.contains('LANGUAGE MISMATCH ERROR:'))
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Suggested Fixes:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '1. Make sure you selected the correct language from the dropdown',
                  style: TextStyle(color: Colors.grey.shade800),
                ),
                Text(
                  '2. Check that your code matches the syntax of $_currentLanguage',
                  style: TextStyle(color: Colors.grey.shade800),
                ),
                Text(
                  '3. If you want to change languages, select the correct one before running',
                  style: TextStyle(color: Colors.grey.shade800),
                ),
              ],
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Suggested Fixes:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '1. Check for typos or missing symbols',
                  style: TextStyle(color: Colors.grey.shade800),
                ),
                Text(
                  '2. Verify all variables are declared',
                  style: TextStyle(color: Colors.grey.shade800),
                ),
                Text(
                  '3. Ensure proper indentation',
                  style: TextStyle(color: Colors.grey.shade800),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildTestResultItem(String result) {
    if (result.startsWith('\nHidden Test Cases:')) {
      final parts = result.split(':')[1].split(',');
      final passed = parts[0].trim().split(' ')[0];
      final failed = parts[1].trim().split(' ')[0];
      final allPassed = failed == '0';

      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: allPassed
              ? Colors.green.withOpacity(0.1)
              : Colors.orange.withOpacity(0.1),
          border: Border.all(
            color: allPassed ? Colors.green.shade200 : Colors.orange.shade200,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  allPassed ? Icons.check_circle : Icons.warning,
                  color: allPassed ? Colors.green : Colors.orange,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  'Hidden Test Cases',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: allPassed ? Colors.green : Colors.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '$passed passed, $failed failed',
              style: TextStyle(
                color: Colors.black87,
              ),
            ),
          ],
        ),
      );
    }

    final isCorrect = result.contains('✅ Correct');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isCorrect
            ? Colors.green.withOpacity(0.1)
            : Colors.red.withOpacity(0.1),
        border: Border.all(
          color: isCorrect ? Colors.green.shade200 : Colors.red.shade200,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isCorrect ? Icons.check_circle : Icons.cancel,
                color: isCorrect ? Colors.green : Colors.red,
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(result.split('\n')[0]),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            result.split('\n')[1],
            style: TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            result.split('\n')[2],
            style: TextStyle(color: Colors.grey[700]),
          ),
          const SizedBox(height: 4),
          Text(
            result.split('\n')[3],
            style: TextStyle(
              color: isCorrect ? Colors.green[700] : Colors.red[700],
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}
