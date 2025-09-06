import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_phosphor_icons/flutter_phosphor_icons.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uicons/uicons.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Multi-Step Form',
      theme: ThemeData(primarySwatch: Colors.blue, fontFamily: 'Inter'),
      home: CustomerForm(),
      debugShowCheckedModeBanner: false,
    );
  }
}

// API Service Class
// API Service Class - Updated for Customer Creation
class ApiService {
  static const String baseUrl = 'http://localhost:2025/api';

  // Method to get stored token
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  // Method to store token (call this after login)
  static Future<void> setToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
  }

  // Method to clear token (call this on logout)
  static Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
  }

  // Login method to get authentication token
  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      final url = Uri.parse('$baseUrl/auth/login');

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'email': email, 'password': password}),
      );

      print('Login Response Status: ${response.statusCode}');
      print('Login Response Body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);

        // Store the token (adjust the key based on your API response structure)
        String token =
            data['token'] ?? data['access_token'] ?? data['authToken'] ?? '';
        if (token.isNotEmpty) {
          await setToken(token);
        }

        return {
          'success': true,
          'data': data,
          'token': token,
          'message': 'Login successful',
        };
      } else {
        return {
          'success': false,
          'error': 'HTTP ${response.statusCode}',
          'message': 'Invalid credentials',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Network error: $e',
        'message': 'Please check your internet connection and try again',
      };
    }
  }

  // Updated method for customer creation
  static Future<Map<String, dynamic>> createCustomer({
    required String firstName,
    required String lastName,
    required String email,
    required String phone,
    required String aadhaar,
    required String pan,
    required String holderName,
    required String bankAccount,
    required String ifsc,
    required String branchName,
    required String branchCode,
    required String city,
    required String state,
    required String address,
    required double amount, // Required amount for group assignment
    required String date, // Required date for group assignment
  }) async {
    try {
      // Get the authentication token
      final token = await getToken();
      if (token == null || token.isEmpty) {
        return {
          'success': false,
          'error': 'Authentication required',
          'message': 'Please login first',
        };
      }

      // Updated endpoint for customer creation
      final url = Uri.parse('$baseUrl/customers');

      final Map<String, dynamic> requestBody = {
        'name': '$firstName $lastName',
        'email': email,
        'phone': phone,
        'adharcard': aadhaar, // Fixed spelling to match backend
        'pancard': pan,
        'address': address,
        'Bank': holderName,
        'IFSC': ifsc,
        'acc': bankAccount,
        'branch': branchName,
        'city': city,
        'state': state,
        'addrass': address,
      };

      // Add amount and date for group assignment (now required)
      requestBody['amount'] = amount;
      requestBody['date'] = date;
      requestBody['emaidate'] = date;

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token', // Add Bearer token
        },
        body: json.encode(requestBody),
      );

      print('Response Status: ${response.statusCode}');
      print('Response Body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {
          'success': true,
          'data': json.decode(response.body),
          'message': 'Customer created successfully',
        };
      } else if (response.statusCode == 401) {
        // Token might be expired, clear it
        await clearToken();
        return {
          'success': false,
          'error': 'Authentication expired',
          'message': 'Please login again',
        };
      } else {
        String errorMessage = 'Failed to create customer';
        try {
          final errorData = json.decode(response.body);
          errorMessage = errorData['message'] ?? errorMessage;
        } catch (e) {
          errorMessage = response.body;
        }

        return {
          'success': false,
          'error': 'HTTP ${response.statusCode}',
          'message': errorMessage,
        };
      }
    } catch (e) {
      print('API Error: $e');
      return {
        'success': false,
        'error': 'Network error: $e',
        'message': 'Please check your internet connection and try again',
      };
    }
  }

  static String generateTemporaryPassword() {
    return 'Temp@${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';
  }
}

class CustomerForm extends StatefulWidget {
  const CustomerForm({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _CustomerFormScreenState createState() => _CustomerFormScreenState();
}

class _CustomerFormScreenState extends State<CustomerForm> {
  int currentStep = 1;
  final _formKey = GlobalKey<FormState>();

  // Step 1 - Personal Details Controllers
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _aadhaarController = TextEditingController();
  final _panController = TextEditingController();

  // Step 2 - Bank Details Controllers
  final _holderNameController = TextEditingController();
  final _bankAccountController = TextEditingController();
  final _ifscController = TextEditingController();
  final _branchNameController = TextEditingController();
  final _branchCodeController = TextEditingController();

  // Step 3 - Address Details Controllers
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _addressController = TextEditingController();

  // Optional fields for group assignment
  final _amountController = TextEditingController();
  final _dateController = TextEditingController();

  bool _isPasswordVisible = false;
  bool _isSubmitting = false;

  void _nextStep() {
    if (_formKey.currentState!.validate()) {
      setState(() {
        if (currentStep < 4) {
          currentStep++;
        }
      });
    }
  }

  void _previousStep() {
    setState(() {
      if (currentStep > 1) {
        currentStep--;
      }
    });
  }

  String formatDate(String input) {
    try {
      final parsedDate = DateFormat("d/M/yyyy").parse(input);
      return DateFormat("yyyy-MM-dd").format(parsedDate); // "2025-08-27"
    } catch (e) {
      print("Date parsing error: $e");
      return input; // fallback
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(color: kPrimaryColor),
              SizedBox(width: 20),
              Text('Creating customer account...'),
            ],
          ),
        );
      },
    );

    try {
      final result = await ApiService.createCustomer(
        firstName: _firstNameController.text,
        lastName: _lastNameController.text,
        email: _emailController.text,
        phone: _phoneController.text,
        aadhaar: _aadhaarController.text,
        pan: _panController.text,
        holderName: _holderNameController.text,
        bankAccount: _bankAccountController.text,
        ifsc: _ifscController.text,
        branchName: _branchNameController.text,
        branchCode: _branchCodeController.text,
        city: _cityController.text,
        state: _stateController.text,
        address: _addressController.text,
        // Optional: Add amount and date if you have those fields
        amount: double.parse(_amountController.text),
        date: formatDate(_dateController.text),
      );

      Navigator.of(context).pop(); // Close loading dialog

      setState(() {
        _isSubmitting = false;
      });

      if (result['success']) {
        _showSuccessDialog(result['data']);
      } else {
        // Handle authentication errors specifically
        if (result['error'] == 'Authentication required' ||
            result['error'] == 'Authentication expired') {
          _showLoginRequiredDialog();
        } else {
          _showErrorDialog(result['message'] ?? 'Unknown error occurred');
        }
      }
    } catch (e) {
      Navigator.of(context).pop(); // Close loading dialog
      setState(() {
        _isSubmitting = false;
      });
      _showErrorDialog('Failed to submit form: $e');
    }
  }

  void _showLoginRequiredDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Authentication Required'),
          content: const Text(
            'You need to login before creating a shareholder account.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                //Navigate to login screen
                Navigator.pushNamed(context, '/login');
              },
              child: const Text('Login'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  void _showSuccessDialog(dynamic userData) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.check_circle,
                  color: Colors.green,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Customer Account Created!',
                  style: TextStyle(fontSize: 18),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Customer account has been successfully created and is ready to use.',
                style: TextStyle(fontSize: 14),
              ),
              if (userData != null && userData['_id'] != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Customer ID:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(userData['_id'].toString()),
                    ],
                  ),
                ),
              ],
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _resetForm();
                // Navigate to dashboard or customer list
                Navigator.pushReplacementNamed(context, '/dashboard');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimaryColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Done', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.error, color: Colors.red, size: 24),
              ),
              const SizedBox(width: 12),
              const Text('Submission Failed', style: TextStyle(fontSize: 18)),
            ],
          ),
          content: Text(message, style: const TextStyle(fontSize: 14)),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimaryColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Try Again',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  void _resetForm() {
    setState(() {
      currentStep = 1;
    });

    // Clear all form fields
    _firstNameController.clear();
    _lastNameController.clear();
    _emailController.clear();
    _phoneController.clear();
    _aadhaarController.clear();
    _panController.clear();
    _holderNameController.clear();
    _bankAccountController.clear();
    _ifscController.clear();
    _branchNameController.clear();
    _branchCodeController.clear();
    _cityController.clear();
    _stateController.clear();
    _addressController.clear();
    _amountController.clear();
    _dateController.clear();
  }

  Widget _buildStep4Confirmation(bool isMobile) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(12),
        color: const Color(0xFFF8F9FA),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildConfirmationSection('Personal Details', [
            _buildConfirmationRow(
              'Name',
              '${_firstNameController.text} ${_lastNameController.text}',
            ),
            _buildConfirmationRow('Email Address', _emailController.text),
            _buildConfirmationRow('Phone Number', _phoneController.text),
            _buildConfirmationRow(
              'Aadhaar Card Number',
              _aadhaarController.text,
            ),
            _buildConfirmationRow('Pan Card Number', _panController.text),
          ]),
          const SizedBox(height: 24),
          _buildConfirmationSection('Bank Details', [
            _buildConfirmationRow(
              'Account Holder Name',
              _holderNameController.text,
            ),
            _buildConfirmationRow(
              'Bank Account Number',
              _bankAccountController.text,
            ),
            _buildConfirmationRow('IFSC Code', _ifscController.text),
            _buildConfirmationRow('Branch Name', _branchNameController.text),
            _buildConfirmationRow('Branch Code', _branchCodeController.text),
          ]),
          const SizedBox(height: 24),
          _buildConfirmationSection('Address Details', [
            _buildConfirmationRow('City', _cityController.text),
            _buildConfirmationRow('State', _stateController.text),
            _buildConfirmationRow('Address', _addressController.text),
          ]),
          const SizedBox(height: 24),
          _buildConfirmationSection('Group Assignment', [
            _buildConfirmationRow('Amount', '₹ ${_amountController.text}'),
            _buildConfirmationRow('Group Date', _dateController.text),
          ]),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F4FD),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: kPrimaryColor.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: kPrimaryColor, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Please review all information carefully. Once confirmed, this data will be submitted to create the customer account and assign them to the specified group.',
                    style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmationSection(String title, List<Widget> rows) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2D3748),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Column(children: rows),
        ),
      ],
    );
  }

  Widget _buildConfirmationRow(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey[100]!, width: 1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value.isEmpty ? 'Not provided' : value,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF2D3748),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kPrimaryColor,
      body: LayoutBuilder(
        builder: (context, constraints) {
          bool isDesktop = constraints.maxWidth > 768;

          if (isDesktop) {
            return _buildDesktopLayout();
          } else {
            return _buildMobileLayout();
          }
        },
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return Row(
      children: [
        SizedBox(width: 300, child: _buildSidebar()),
        Expanded(
          child: Container(
            margin: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: _buildMainContent(),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout() {
    return Container(
      color: Colors.white,
      child: SafeArea(child: _buildMainContent(isMobile: true)),
    );
  }

  Widget _buildSidebar() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 40),
          _buildStepItem(
            1,
            'Personal Details',
            currentStep > 1,
            isActive: currentStep == 1,
          ),
          _buildConnector(currentStep > 1),
          _buildStepItem(
            2,
            'Bank Details',
            currentStep > 2,
            isActive: currentStep == 2,
          ),
          _buildConnector(currentStep > 2),
          _buildStepItem(
            3,
            'Address Details',
            currentStep > 3,
            isActive: currentStep == 3,
          ),
          _buildConnector(currentStep > 3),
          _buildStepItem(4, 'Confirmation', false, isActive: currentStep == 4),
          const Spacer(),
          Center(
            child: Image.asset(
              'assets/images/emp_bg.png',
              height: 150,
              width: 150,
            ),
          ),
          SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildStepItem(
    int step,
    String title,
    bool completed, {
    bool isActive = false,
  }) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(3),
          width: 45,
          height: 45,
          decoration: BoxDecoration(
            color: isActive ? Colors.white.withOpacity(.2) : Colors.transparent,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Container(
            padding: EdgeInsets.all(3),
            decoration: BoxDecoration(
              color:
                  isActive ? Colors.white.withOpacity(.5) : Colors.transparent,
              borderRadius: BorderRadius.circular(19),
            ),
            child: Container(
              decoration: BoxDecoration(
                color:
                    completed
                        ? Colors.white
                        : (isActive ? Colors.white : Colors.transparent),
                border: Border.all(
                  color: Colors.white.withOpacity(0.5),
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child:
                    completed
                        ? Icon(
                          PhosphorIcons.check,
                          color: kPrimaryColor,
                          size: 18,
                        )
                        : Text(
                          step.toString(),
                          style: TextStyle(
                            color: isActive ? kPrimaryColor : Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'STEP $step',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                title,
                style: TextStyle(
                  color:
                      (isActive == completed) ? Colors.white70 : Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildConnector(bool completed) {
    return Container(
      margin: const EdgeInsets.only(left: 20, top: 8, bottom: 8),
      width: 2,
      height: 30,
      color: completed ? Colors.white : Colors.white.withOpacity(0.3),
    );
  }

  Widget _buildMainContent({bool isMobile = false}) {
    return Padding(
      padding: EdgeInsets.all(isMobile ? 16 : 32).copyWith(bottom: 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildMobileHeader(),
          const SizedBox(height: 24),
          Text(
            _getStepTitle(),
            style: TextStyle(
              fontSize: isMobile ? 24 : 28,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF2D3748),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _getStepDescription(),
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
          const SizedBox(height: 32),
          Expanded(
            child: Form(key: _formKey, child: _buildCurrentStepForm(isMobile)),
          ),
        ],
      ),
    );
  }

  String _getStepTitle() {
    switch (currentStep) {
      case 1:
        return 'Customer Personal Details';
      case 2:
        return 'Add bank details';
      case 3:
        return 'Add address details';
      case 4:
        return 'Confirm customer information';
      default:
        return 'Complete customer profile';
    }
  }

  String _getStepDescription() {
    switch (currentStep) {
      case 1:
        return 'Enter customer personal information for account setup';
      case 2:
        return 'Please provide customer bank account details';
      case 3:
        return 'Please provide customer address and location information';
      case 4:
        return 'Please review customer information and confirm to create account';
      default:
        return 'Please complete all required customer information';
    }
  }

  Widget _buildMobileHeader() {
    return SizedBox(
      height: 40,
      child: Row(
        children: [
          if (currentStep == 1)
            IconButton(
              onPressed: () {
                Navigator.pop(context);
              },
              icon: Icon(
                UIcons.regularRounded.angle_small_left,
                color: kPrimaryColor,
              ),
            ),
          if (currentStep > 1)
            IconButton(
              onPressed: _previousStep,
              icon: Icon(
                UIcons.regularRounded.angle_small_left,
                color: kPrimaryColor,
              ),
            ),
          const SizedBox(width: 8),
          Text(
            'STEP $currentStep OF 4',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: kPrimaryColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentStepForm(bool isMobile) {
    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Column(
                key: ValueKey(currentStep),
                children: [
                  if (currentStep == 1) _buildStep1Fields(isMobile),
                  if (currentStep == 2) _buildStep2Fields(isMobile),
                  if (currentStep == 3) _buildStep3Fields(isMobile),
                  if (currentStep == 4) _buildStep4Confirmation(isMobile),
                ],
              ),
            ),
            const SizedBox(height: 32),
            _buildNavigationButtons(),
            SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildStep1Fields(bool isMobile) {
    if (isMobile) {
      return Column(
        children: [
          _buildTextField('First Name', _firstNameController, isRequired: true),
          const SizedBox(height: 16),
          _buildTextField('Last Name', _lastNameController, isRequired: true),
          const SizedBox(height: 16),
          _buildTextField(
            'Email Address',
            _emailController,
            keyboardType: TextInputType.emailAddress,
            isRequired: true,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            'Phone Number',
            _phoneController,
            keyboardType: TextInputType.phone,
            isRequired: true,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            'Aadhaar Card Number',
            _aadhaarController,
            keyboardType: TextInputType.number,
            isRequired: true,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            'Pan Card Number',
            _panController,
            keyboardType: TextInputType.visiblePassword,
            isRequired: true,
            isUpperCase: true,
          ),
        ],
      );
    } else {
      return Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  'First Name',
                  _firstNameController,
                  isRequired: true,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildTextField(
                  'Last Name',
                  _lastNameController,
                  isRequired: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  'Email Address',
                  _emailController,
                  keyboardType: TextInputType.emailAddress,
                  isRequired: true,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildTextField(
                  'Phone Number',
                  _phoneController,
                  keyboardType: TextInputType.phone,
                  isRequired: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  'Aadhaar Card Number',
                  _aadhaarController,
                  keyboardType: TextInputType.number,
                  isRequired: true,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildTextField(
                  'Pan Card Number',
                  _panController,
                  keyboardType: TextInputType.visiblePassword,
                  isRequired: true,
                  isUpperCase: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      );
    }
  }

  Widget _buildStep2Fields(bool isMobile) {
    if (isMobile) {
      return Column(
        children: [
          _buildTextField(
            'Account Holder Name',
            _holderNameController,
            keyboardType: TextInputType.text,
            isRequired: true,
            isUpperCase: true,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            'Bank Account Number',
            _bankAccountController,
            keyboardType: TextInputType.number,
            isRequired: true,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            'IFSC Code',
            _ifscController,
            isRequired: true,
            isUpperCase: true,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            'Branch Name',
            _branchNameController,
            keyboardType: TextInputType.text,
            isRequired: true,
            isUpperCase: true,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            'Branch Code',
            _branchCodeController,
            keyboardType: TextInputType.visiblePassword,
            isRequired: true,
            isUpperCase: true,
          ),
        ],
      );
    } else {
      return Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  'Account Holder Name',
                  _holderNameController,
                  keyboardType: TextInputType.text,
                  isRequired: true,
                  isUpperCase: true,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildTextField(
                  'Bank Account Number',
                  _bankAccountController,
                  keyboardType: TextInputType.number,
                  isRequired: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildTextField(
            'IFSC Code',
            _ifscController,
            isRequired: true,
            isUpperCase: true,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  'Branch Name',
                  _branchNameController,
                  keyboardType: TextInputType.text,
                  isRequired: true,
                  isUpperCase: true,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildTextField(
                  'Branch Code',
                  _branchCodeController,
                  keyboardType: TextInputType.visiblePassword,
                  isRequired: true,
                  isUpperCase: true,
                ),
              ),
            ],
          ),
        ],
      );
    }
  }

  Widget _buildStep3Fields(bool isMobile) {
    if (isMobile) {
      return Column(
        children: [
          _buildTextField('City', _cityController,
              keyboardType: TextInputType.text, isRequired: true),
          const SizedBox(height: 16),
          _buildTextField('State', _stateController,
              keyboardType: TextInputType.text, isRequired: true),
          const SizedBox(height: 16),
          _buildTextField('Address', _addressController,
              keyboardType: TextInputType.multiline,
              isRequired: true,
              maxLines: 3),
          const SizedBox(height: 24),
          // Divider
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                Expanded(child: Divider(color: Colors.grey[300])),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'Group Assignment',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
                Expanded(child: Divider(color: Colors.grey[300])),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildAmountDropdown(),
          const SizedBox(height: 16),
          _buildGroupDateDropdown(),
        ],
      );
    } else {
      return Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildTextField('City', _cityController,
                    keyboardType: TextInputType.text, isRequired: true),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildTextField('State', _stateController,
                    keyboardType: TextInputType.text, isRequired: true),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildTextField('Address', _addressController,
              keyboardType: TextInputType.multiline,
              isRequired: true,
              maxLines: 3),
          const SizedBox(height: 24),
          // Divider
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                Expanded(child: Divider(color: Colors.grey[300])),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'Group Assignment Details',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
                Expanded(child: Divider(color: Colors.grey[300])),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildAmountDropdown()),
              const SizedBox(width: 16),
              Expanded(child: _buildGroupDateDropdown()),
            ],
          ),
        ],
      );
    }
  }


  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    TextInputType? keyboardType,
    bool isRequired = false,
    bool isUpperCase = false,
    int maxLines = 1,
    String? prefixText,
  }) {
    List<TextInputFormatter> inputFormatters = [];

    // Add uppercase formatter for bank fields
    if (isUpperCase) {
      inputFormatters.add(UpperCaseTextInputFormatter());
    }

    if (label == 'Aadhaar Card Number') {
      inputFormatters.add(FilteringTextInputFormatter.digitsOnly);
      inputFormatters.add(LengthLimitingTextInputFormatter(12));
    } else if (label == 'Pan Card Number') {
      inputFormatters.add(
        FilteringTextInputFormatter.allow(RegExp(r'[A-Z0-9]')),
      );
      inputFormatters.add(LengthLimitingTextInputFormatter(10));
    } else if (label == 'Phone Number') {
      inputFormatters.add(FilteringTextInputFormatter.digitsOnly);
      inputFormatters.add(LengthLimitingTextInputFormatter(10));
    } else if (label == 'Amount') {
      inputFormatters.add(
        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Color(0xFF4A5568),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          cursorColor: kPrimaryColor,
          maxLines: maxLines,
          inputFormatters: inputFormatters,
          validator:
              isRequired
                  ? (value) {
                    if (value == null || value.isEmpty) {
                      return 'This field is required';
                    }
                    if (label == 'Email Address' && !value.contains('@')) {
                      return 'Please enter a valid email address';
                    }
                    if (label == 'Aadhaar Card Number' && value.length != 12) {
                      return 'Aadhaar number should be 12 digits';
                    }
                    if (label == 'Pan Card Number' &&
                        value.length != 10 &&
                        !RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]{1}').hasMatch(value)) {
                      return 'Enter valid PAN (e.g. ABCDE1234F)';
                    }
                    if (label == 'IFSC Code' &&
                        !RegExp(r'^[A-Z]{4}0[A-Z0-9]{6}').hasMatch(value)) {
                      return 'Enter valid IFSC (e.g. SBIN0000123)';
                    }
                    if (label == 'Phone Number' && value.length != 10) {
                      return 'Phone number should be 10 digits';
                    }
                    if (label == 'Amount') {
                      final amount = double.tryParse(value);
                      if (amount == null || amount <= 0) {
                        return 'Please enter a valid amount';
                      }
                    }
                    return null;
                  }
                  : null,
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFFF7FAFC),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: kPrimaryColor),
            ),
            errorStyle: TextStyle(
              color: kPrimaryColor,
              fontWeight: FontWeight.w500,
            ),
            prefixText: prefixText,
            prefixStyle: const TextStyle(
              color: Color(0xFF4A5568),
              fontWeight: FontWeight.w500,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownField<T>({
    required String label,
    required List<DropdownMenuItem<T>> items,
    required T? value,
    required void Function(T?) onChanged,
    bool isRequired = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Color(0xFF4A5568),
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField2<T>(
          isExpanded: true,
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFFF7FAFC),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: kPrimaryColor),
            ),
            errorStyle: const TextStyle(
              color: kPrimaryColor,
              fontWeight: FontWeight.w500,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
          ),
          value: value,
          items: items,
          onChanged: onChanged,
          validator: isRequired
              ? (v) => v == null ? "This field is required" : null
              : null,
          dropdownStyleData: DropdownStyleData(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          menuItemStyleData: const MenuItemStyleData(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          ),
        ),
      ],
    );
  }

  Widget _buildAmountDropdown() {
    final List<int> amounts = List.generate(10, (i) => (i + 1) * 1000);

    return _buildDropdownField<int>(
      label: "Amount",
      value: _amountController.text.isNotEmpty
          ? int.tryParse(_amountController.text)
          : null,
      items: amounts
          .map((v) => DropdownMenuItem<int>(
        value: v,
        child: Text("₹ $v"),
      ))
          .toList(),
      onChanged: (v) {
        if (v != null) _amountController.text = v.toString();
      },
      isRequired: true,
    );
  }

  // 🔹 Group Date Dropdown (only 10 & 20 rule)
 Widget _buildGroupDateDropdown() {
  DateTime now = DateTime.now();
  int day = now.day;

  DateTime option1;
  DateTime option2;

  if (day >= 11) {
    option1 = DateTime(now.year, now.month, 20);
    option2 = DateTime(now.year, now.month + 1, 10);
  } else {
    option1 = DateTime(now.year, now.month, 10);
    option2 = DateTime(now.year, now.month, 20);
  }

  final List<DateTime> options = [option1, option2];

  // Parse controller value safely (if any)
  DateTime? selectedDate;
  if (_dateController.text.isNotEmpty) {
    try {
      selectedDate = DateTime.parse(_dateController.text); // backend format
    } catch (e) {
      selectedDate = null;
    }
  }

  return _buildDropdownField<DateTime>(
    label: "Group Date",
    value: selectedDate,
    items: options
        .map((date) => DropdownMenuItem<DateTime>(
              value: date,
              child: Text(
                // Show as dd-MM-yyyy for user
                "${date.day.toString().padLeft(2, '0')}-"
                "${date.month.toString().padLeft(2, '0')}-"
                "${date.year}",
              ),
            ))
        .toList(),
    onChanged: (v) {
      if (v != null) {
        // Save in yyyy-MM-dd for backend
        _dateController.text =
            "${v.year}-${v.month.toString().padLeft(2, '0')}-${v.day.toString().padLeft(2, '0')}";

        // (Optional) print what user sees
        print(
            "Selected for display: ${v.day.toString().padLeft(2, '0')}-${v.month.toString().padLeft(2, '0')}-${v.year}");
        print("Saved for backend: ${_dateController.text}");
      }
    },
    isRequired: true,
  );
}



  Widget _buildNavigationButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (currentStep > 1) ...[
          OutlinedButton(
            onPressed: _previousStep,
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: kPrimaryColor),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
            ),
            child: Text(
              'Previous',
              style: TextStyle(
                color: kPrimaryColor,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(width: 16),
        ],
        ElevatedButton(
          onPressed:
              _isSubmitting
                  ? null
                  : (currentStep == 4 ? _submitForm : _nextStep),
          style: ElevatedButton.styleFrom(
            backgroundColor: kPrimaryColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
          ),
          child:
              _isSubmitting
                  ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Submitting...',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  )
                  : Text(
                    currentStep == 4 ? 'Submit' : 'Next',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    // Step 1 controllers
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _aadhaarController.dispose();
    _panController.dispose();

    // Step 2 controllers
    _holderNameController.dispose();
    _bankAccountController.dispose();
    _ifscController.dispose();
    _branchNameController.dispose();
    _branchCodeController.dispose();

    // Step 3 controllers
    _cityController.dispose();
    _stateController.dispose();
    _addressController.dispose();

    // Group assignment controllers
    _amountController.dispose();
    _dateController.dispose();

    super.dispose();
  }
}

// Custom TextInputFormatter to convert input to uppercase
class UpperCaseTextInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
);
}
}

const kPrimaryColor = Color(0xFFc49253);
const kPrimaryColorlight = Color(0xffc39c6c);
const kSecondaryColor = Color(0xffe2d5ca);
const kBlueColor = Color(0xFF1A1D29);
const kBackgroundColor = Color(0xFFF8F9FB);

const defaultPadding = 16.0;