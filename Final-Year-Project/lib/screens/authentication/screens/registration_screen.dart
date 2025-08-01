import 'package:flutter/material.dart';
import 'package:fyp/utils/flashbar_helper.dart';
import 'package:provider/provider.dart';

import '../../../models/user.dart';
import '../../../providers/AuthProvider.dart';
import '../../../utils/snackbar_helper.dart';
import '../../home/home_navigation.dart';
import '../screens/login_screen.dart';
import '../screens/registration_image_screen.dart';
import '../widgets/registration_type.dart';
import '../widgets/button.dart';
import '../widgets/google_button.dart';
import '../widgets/input_field.dart';
import '../widgets/link_button.dart';
import 'email_verification.dart';

class SignUp extends StatefulWidget {
  const SignUp({Key? key}) : super(key: key);

  @override
  State<SignUp> createState() => _SignUpState();
}

class _SignUpState extends State<SignUp> {
  final TextEditingController _emailController    = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  bool _isSignUpLoading = false;
  bool _isGoogleSignUpLoading = false;
  bool _isPasswordVisible        = false;
  bool _isConfirmPasswordVisible = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }



  Future<void> _submitForm(AuthProvider authProvider) async {
    setState(() => _isSignUpLoading = true);

    final email           = _emailController.text.trim();
    final password        = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (email.isEmpty) {
      SnackbarHelper.showErrorSnackbar(context, "Please enter your email");
      setState(() => _isSignUpLoading = false);
      return;
    }
    if (password.isEmpty) {
      SnackbarHelper.showErrorSnackbar(context, "Please enter your password");
      setState(() => _isSignUpLoading = false);
      return;
    }
    if (confirmPassword.isEmpty) {
      SnackbarHelper.showErrorSnackbar(context, "Please confirm your password");
      setState(() => _isSignUpLoading = false);
      return;
    }
    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(email)) {
      SnackbarHelper.showErrorSnackbar(context, "Please enter a valid email address");
      setState(() => _isSignUpLoading = false);
      return;
    }
    if (password.length < 6) {
      SnackbarHelper.showErrorSnackbar(context, "Password must be at least 6 characters");
      setState(() => _isSignUpLoading = false);
      return;
    }
    if (!RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password)) {
      SnackbarHelper.showErrorSnackbar(context, "Password must contain at least one special character");
      setState(() => _isSignUpLoading = false);
      return;
    }
    if (password != confirmPassword) {
      SnackbarHelper.showErrorSnackbar(context, "Passwords do not match");
      setState(() => _isSignUpLoading = false);
      return;
    }

    authProvider.clearMessages();
    if (!mounted) return;

    final message = await authProvider.registerWithEmail(
      User(
        email: email,
        username: email.split("@")[0],
        password: password,
      ),
    );

    if (!mounted) return;
    setState(() => _isSignUpLoading = false);

    if (message != null) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => EmailVerification(email: email)),
      );
      FlushbarHelper.show(context, message: message);
    } else {
      FlushbarHelper.show(
        context,
        message: authProvider.error ?? "Registration Failed",
        icon: Icons.error,
        backgroundColor: Colors.red,
      );
    }
  }

  Future<void> _handleGoogleSignUp(AuthProvider authProvider) async {
    setState(() => _isGoogleSignUpLoading = true);
    try {
      authProvider.clearMessages();
      await authProvider.userGoogleData();
      if (!mounted) return;

      if (authProvider.user?.email == null) {
        SnackbarHelper.showErrorSnackbar(context, "Failed to get Google account data");
        setState(() => _isGoogleSignUpLoading = false);
        return;
      }

      await authProvider.signUpWithGoogle(
        idToken: authProvider.googleIdToken,
        user: User(
          email: authProvider.user!.email,
          username: authProvider.user!.username ?? authProvider.user!.email,
        ),
      );

      if (!mounted) return;
      setState(() => _isGoogleSignUpLoading = false);

      if (authProvider.jwtToken != null &&
          authProvider.user!.isVerified &&
          authProvider.user!.profileImageUrl!.isEmpty) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const RegistrationImage()),
              (route) => false,
        );
        SnackbarHelper.showSuccessSnackbar(context, "Google Registration successful");
      } else {
        SnackbarHelper.showErrorSnackbar(
          context,
          "Google registration failed,${authProvider.error.toString()}",
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isGoogleSignUpLoading = false);
      SnackbarHelper.showErrorSnackbar(
        context,
        authProvider.error ?? "Google sign-up failed",
      );
    }
  }


  void _togglePasswordVisibility() {
    setState(() => _isPasswordVisible = !_isPasswordVisible);
  }

  void _toggleConfirmPasswordVisibility() {
    setState(() => _isConfirmPasswordVisible = !_isConfirmPasswordVisible);
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final size = MediaQuery.of(context).size;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: size.width * 0.06).copyWith(
            top: size.height * 0.02,
            bottom: size.height * 0.02,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildLogo(),
              _buildTitle(),
              _buildEmailField(),
              const SizedBox(height: 10),
              _buildPasswordField(),
              const SizedBox(height: 10),
              _buildConfirmPasswordField(),
              const SizedBox(height: 10),
              _buildSignUpButton(authProvider),
              _buildSeparator(),
              _buildGoogleButton(authProvider),
              _buildLoginLink(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    final w = MediaQuery.of(context).size.width;
    return Center(
      child: Image(
        image: const AssetImage("assets/logo.png"),
        width: w * 0.4,
      ),
    );
  }

  Widget _buildTitle() {
    return const Column(
      children: [
        Text(
          "Create an account",
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 8),
        Text(
          "Enter your details to register",
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w400),
        ),
        SizedBox(height: 24),
      ],
    );
  }

  Widget _buildEmailField() {
    return InputField(
      icon: const Icon(Icons.email, color: Colors.blue),
      keyboardType: TextInputType.emailAddress,
      hint: "sample@gmail.com",
      label: "Email",
      controller: _emailController,
      validator: null,
    );
  }

  Widget _buildPasswordField() {
    return InputField(
      icon: const Icon(Icons.lock, color: Colors.blue),
      icon2: IconButton(
        icon: Icon(
          _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
          color: Colors.grey,
        ),
        onPressed: _togglePasswordVisibility,
      ),
      keyboardType: TextInputType.visiblePassword,
      hint: "********",
      label: "Password",
      obscureText: !_isPasswordVisible,
      controller: _passwordController,
      validator: null,
    );
  }

  Widget _buildConfirmPasswordField() {
    return InputField(
      icon: const Icon(Icons.lock, color: Colors.blue),
      icon2: IconButton(
        icon: Icon(
          _isConfirmPasswordVisible ? Icons.visibility : Icons.visibility_off,
          color: Colors.grey,
        ),
        onPressed: _toggleConfirmPasswordVisibility,
      ),
      keyboardType: TextInputType.visiblePassword,
      hint: "********",
      label: "Confirm Password",
      obscureText: !_isConfirmPasswordVisible,
      controller: _confirmPasswordController,
      validator: null,
    );
  }

  Widget _buildSignUpButton(AuthProvider authProvider) {
    return AuthenticationButton(
      text: 'Sign Up',
      onPressed: _isSignUpLoading ? null : () => _submitForm(authProvider),
      isLoading: _isSignUpLoading,
      backgroundColor: Colors.blue,
      textColor: Colors.white,
      fontSize: 18,
      fontWeight: FontWeight.bold,
      borderRadius: 10,
      padding: const EdgeInsets.symmetric(vertical: 12),
    );
  }


  Widget _buildSeparator() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 24),
      child: Row(
        children: [
          Expanded(child: Divider(thickness: 1)),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text("or", style: TextStyle(fontSize: 16)),
          ),
          Expanded(child: Divider(thickness: 1)),
        ],
      ),
    );
  }
  Widget _buildGoogleButton(AuthProvider authProvider) {
    return GoogleButton(
      onPressed: _isGoogleSignUpLoading ? null : () => _handleGoogleSignUp(authProvider),
      isLoading: _isGoogleSignUpLoading,
      text: "Continue with Google",
      borderRadius: 10,
      padding: const EdgeInsets.symmetric(vertical: 12),
      iconSize: 24,
      spacing: 12,
      fontSize: 16,
      fontWeight: FontWeight.bold,
    );
  }


  Widget _buildLoginLink() {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Center(
        child: LinkButton(
          desc: "Already have an account? ",
          text: "Login",
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const LoginScreen()),
          ),
        ),
      ),
    );
  }
}
