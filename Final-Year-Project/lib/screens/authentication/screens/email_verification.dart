import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fyp/screens/authentication/screens/registration_image_screen.dart';
import 'package:fyp/screens/authentication/widgets/verification_input_field.dart';
import 'package:fyp/screens/home/home_navigation.dart';
import 'package:provider/provider.dart';
import '../../../models/user.dart';
import '../../../providers/AuthProvider.dart';
import '../../../utils/snackbar_helper.dart';
import '../screens/login_screen.dart';
import 'package:fyp/screens/home/widgets/navigation_menu.dart';

class EmailVerification extends StatefulWidget {
  final String email;

  const EmailVerification({Key? key, required this.email}) : super(key: key);

  @override
  State<EmailVerification> createState() => _EmailVerificationState();
}

class _EmailVerificationState extends State<EmailVerification> {
  final List<TextEditingController> _controllers =
  List.generate(6, (_) => TextEditingController());
  bool _isVerifying = false;

  String get verificationCode => _controllers.map((c) => c.text).join();

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _submitVerification() async {
    final code = verificationCode;
    if (code.length < 6) {
      SnackbarHelper.showErrorSnackbar(
          context, "Please enter a complete 6-digit code");
      return;
    }
    setState(() {
      _isVerifying = true;
    });
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    try {
      final bool isSuccess = await authProvider.verifyEmail(
        code,
        User(email: widget.email, username: widget.email, isVerified: false),
      );

      if (isSuccess && authProvider.user!.profileImageUrl=='') {
        SnackbarHelper.showSuccessSnackbar(
            context, "Verification successful,Please provide front face image for proceeding next!");
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => RegistrationImage()),
              (route) => false,
        );
      } else {
        SnackbarHelper.showErrorSnackbar(
            context, "Verification failed, please try again.");
      }
    } catch (e) {
      SnackbarHelper.showErrorSnackbar(
          context, "Verification failed, please try again.");
    } finally {
      setState(() {
        _isVerifying = false;
      });
    }
  }

  Future<void> _resendCode() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user =
    User(email: widget.email, username: widget.email, isVerified: false);
    final success = await authProvider.resendVerificationCode(user);
    if (success) {
      SnackbarHelper.showSuccessSnackbar(
          context, "Verification code resent successfully!");
    } else {
      SnackbarHelper.showErrorSnackbar(
          context, "Failed to resend verification code. Please try again.");
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return Scaffold(
      appBar: AppBar(
        title: Text("Verify Email",style: TextStyle(fontWeight: FontWeight.bold,fontSize: 22),),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const LoginScreen()),
            );
          },
        ),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 40),
              _buildLogo(width),
              const SizedBox(height: 20),
              _buildTitle(width),
              const SizedBox(height: 10),
              _buildDescription(width),
              const SizedBox(height: 20),
              _buildCodeInputRow(width),
              Padding(
                padding: EdgeInsets.only(right: width * 0.02, top: 8),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _resendCode,
                    child: const Text(
                      "Resend Code",
                      style: TextStyle(color: Colors.blue),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _isVerifying ? null : _submitVerification,
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: Colors.blue,
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: _isVerifying
                    ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    valueColor:
                    AlwaysStoppedAnimation<Color>(Colors.white),
                    strokeWidth: 2,
                  ),
                )
                    : const Text("Verify"),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogo(double width) {
    return Image.asset(
      "assets/logo.png",
      width: width * 0.4,
    );
  }

  Widget _buildTitle(double width) {
    return Text(
      "Enter Verification Code",
      textAlign: TextAlign.center,
      style: TextStyle(fontSize: width * 0.07, fontWeight: FontWeight.w800),
    );
  }

  Widget _buildDescription(double width) {
    return Text(
      "Please enter the 6-digit code sent to your email address to verify your identity",
      textAlign: TextAlign.center,
      style: TextStyle(fontSize: width * 0.04, fontWeight: FontWeight.w400),
    );
  }

  Widget _buildCodeInputRow(double width) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(6, (index) {
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: width * 0.013),
          child: VerificationInputField(
            controller: _controllers[index],
            keyboardType: TextInputType.number,
            onChanged: (value) {
              if (value.isNotEmpty && index < 5) {
                FocusScope.of(context).nextFocus();
              } else if (value.isEmpty && index > 0) {
                FocusScope.of(context).previousFocus();
              }
            },
          ),
        );
      }),
    );
  }
}
