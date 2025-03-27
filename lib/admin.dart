import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:codeed/api.dart';
import 'package:codeed/login.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _sampleInputController = TextEditingController();
  final TextEditingController _sampleOutputController = TextEditingController();
  final TextEditingController _constraintsController = TextEditingController();
  final TextEditingController _inputController = TextEditingController();
  final TextEditingController _outputController = TextEditingController();
  final List<TestCase> _testCases = [];
  bool _isHiddenTestCase = false;

  final Color primaryColor = const Color(0xFF00158F);
  final Color backgroundColor = Colors.white;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _sampleInputController.dispose();
    _sampleOutputController.dispose();
    _constraintsController.dispose();
    _inputController.dispose();
    _outputController.dispose();
    super.dispose();
  }

  void _navigateToLogin(BuildContext context) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (Route<dynamic> route) => false,
    );
  }

  Widget _buildFormField({
    required TextEditingController controller,
    required String label,
    required String? Function(String?) validator,
    String? hint,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: Colors.grey.shade50,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            contentPadding: const EdgeInsets.all(16),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: primaryColor,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: primaryColor,
          ),
        ),
      ],
    );
  }

  Widget _buildTestCaseDetail(String label, String value) {
    return RichText(
      text: TextSpan(
        style: const TextStyle(color: Colors.black),
        children: [
          TextSpan(
            text: '$label: ',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          TextSpan(
            text: value,
            style: const TextStyle(fontFamily: 'monospace'),
          ),
        ],
      ),
    );
  }

  Widget _buildTestCaseForm() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Hidden Test Case:'),
              Switch(
                value: _isHiddenTestCase,
                onChanged: (value) => setState(() => _isHiddenTestCase = value),
                activeColor: primaryColor,
              ),
              if (_isHiddenTestCase)
                const Text(' (For evaluation only)',
                    style: TextStyle(color: Colors.red)),
            ],
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _inputController,
            decoration: InputDecoration(
              labelText: 'Input',
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _outputController,
            decoration: InputDecoration(
              labelText: 'Expected Output',
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Add Test Case'),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
              ),
              onPressed: _addTestCase,
            ),
          ),
        ],
      ),
    );
  }

  void _addTestCase() {
    if (_inputController.text.isNotEmpty && _outputController.text.isNotEmpty) {
      setState(() {
        _testCases.add(TestCase(
          input: _inputController.text,
          expectedOutput: _outputController.text,
          isHidden: _isHiddenTestCase,
        ));
        _inputController.clear();
        _outputController.clear();
        _isHiddenTestCase = false;
      });
    }
  }

  Widget _buildTestCaseList() {
    if (_testCases.isEmpty) return const SizedBox();

    return Column(
      children: [
        if (_testCases.any((tc) => !tc.isHidden))
          _buildTestCaseSection('Visible Test Cases', false),
        if (_testCases.any((tc) => tc.isHidden))
          _buildTestCaseSection('Hidden Test Cases', true),
      ],
    );
  }

  Widget _buildTestCaseSection(String title, bool isHidden) {
    final cases = _testCases.where((tc) => tc.isHidden == isHidden).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isHidden ? Colors.red : null,
          ),
        ),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          margin: const EdgeInsets.only(bottom: 20),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: cases.length,
            separatorBuilder: (context, index) => Divider(
              color: Colors.grey.shade300,
              height: 1,
            ),
            itemBuilder: (context, index) {
              final testCase = cases[index];
              return ListTile(
                title: Text(
                  'Test Case ${_testCases.indexOf(testCase) + 1}',
                  style: TextStyle(
                    color: testCase.isHidden ? Colors.red : null,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTestCaseDetail('Input', testCase.input),
                    _buildTestCaseDetail(
                        'Expected Output', testCase.expectedOutput),
                  ],
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _removeTestCase(testCase),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _removeTestCase(TestCase testCase) {
    setState(() => _testCases.remove(testCase));
  }

  Future<void> _submitQuestion() async {
    if (_formKey.currentState!.validate()) {
      if (_testCases.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please add at least one test case'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      try {
        final supabase = Supabase.instance.client;
        final questionResponse = await supabase
            .from('questions')
            .insert({
              'title': _titleController.text,
              'description': _descriptionController.text,
              'sample_input': _sampleInputController.text,
              'sample_output': _sampleOutputController.text,
              'constraints': _constraintsController.text,
              'created_at': DateTime.now().toIso8601String(),
            })
            .select('id')
            .single();

        await supabase.from('test_cases').insert(_testCases
            .map((tc) => {
                  'question_id': questionResponse['id'],
                  'input': tc.input,
                  'expected_output': tc.expectedOutput,
                  'is_hidden': tc.isHidden,
                })
            .toList());

        final appState = Provider.of<AppState>(context, listen: false);
        appState.addQuestion(Question(
          id: questionResponse['id'].toString(),
          title: _titleController.text,
          description: _descriptionController.text,
          sampleInput: _sampleInputController.text,
          sampleOutput: _sampleOutputController.text,
          constraints: _constraintsController.text,
          testCases: List.from(_testCases),
        ));

        _clearForm();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Question added successfully!'),
            backgroundColor: primaryColor,
          ),
        );
      } catch (error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${error.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _clearForm() {
    _titleController.clear();
    _descriptionController.clear();
    _sampleInputController.clear();
    _sampleOutputController.clear();
    _constraintsController.clear();
    _inputController.clear();
    _outputController.clear();
    setState(() {
      _testCases.clear();
      _isHiddenTestCase = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 600;
    final isMediumScreen = screenSize.width >= 600 && screenSize.width < 1200;
    final isLargeScreen = screenSize.width >= 1200;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: primaryColor,
        title: const Text('Admin Panel'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () => _confirmClearAll(),
            tooltip: 'Clear All Questions',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _navigateToLogin(context),
            tooltip: 'Logout',
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: Container(
            width: isLargeScreen
                ? screenSize.width * 0.7
                : isMediumScreen
                    ? screenSize.width * 0.85
                    : screenSize.width,
            padding: EdgeInsets.symmetric(
              horizontal: isSmallScreen ? 16.0 : 24.0,
              vertical: 20.0,
            ),
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Create New Question',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 24),
                      _buildFormField(
                        controller: _titleController,
                        label: 'Question Title',
                        hint: 'Enter a clear, concise title',
                        validator: (value) => value?.isEmpty ?? true
                            ? 'Please enter a title'
                            : null,
                      ),
                      const SizedBox(height: 20),
                      _buildFormField(
                        controller: _descriptionController,
                        label: 'Question Description',
                        hint: 'Provide detailed instructions',
                        maxLines: 5,
                        validator: (value) => value?.isEmpty ?? true
                            ? 'Please enter a description'
                            : null,
                      ),
                      const SizedBox(height: 20),
                      _buildSectionHeader('Sample Input/Output'),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _buildFormField(
                              controller: _sampleInputController,
                              label: 'Sample Input',
                              validator: (value) => value?.isEmpty ?? true
                                  ? 'Please provide sample input'
                                  : null,
                              maxLines: 3,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildFormField(
                              controller: _sampleOutputController,
                              label: 'Sample Output',
                              validator: (value) => value?.isEmpty ?? true
                                  ? 'Please provide sample output'
                                  : null,
                              maxLines: 3,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      _buildFormField(
                        controller: _constraintsController,
                        label: 'Constraints',
                        validator: (value) => value?.isEmpty ?? true
                            ? 'Please specify constraints'
                            : null,
                        maxLines: 3,
                      ),
                      const SizedBox(height: 28),
                      _buildSectionHeader('Test Cases'),
                      const SizedBox(height: 12),
                      _buildTestCaseList(),
                      _buildSectionHeader('Add New Test Case'),
                      const SizedBox(height: 12),
                      _buildTestCaseForm(),
                      const SizedBox(height: 32),
                      Center(
                        child: ElevatedButton(
                          onPressed: _submitQuestion,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 40, vertical: 16),
                          ),
                          child: const Text('Submit Question'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmClearAll() async {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Clear All'),
          content: const Text(
              'This will delete ALL questions and test cases. Continue?'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                try {
                  await Supabase.instance.client
                      .from('questions')
                      .delete()
                      .gt('id', 0);
                  Provider.of<AppState>(context, listen: false)
                      .clearQuestions();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('All questions cleared')),
                  );
                } catch (error) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $error')),
                  );
                }
              },
              child: const Text('Confirm', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }
}
