import 'package:flutter/material.dart';
import 'package:fyp/screens/authentication/screens/registration_image_screen.dart';
import 'package:provider/provider.dart';
import '../../../models/user.dart';
import '../../../providers/AuthProvider.dart';
import '../../../utils/app_page_route.dart';
import '../../../utils/email_validator.dart';
import '../../../utils/navigation_helper.dart';
import '../../../utils/snackbar_helper.dart';
import '../../home/home_navigation.dart';
import '../screens/email_verification.dart';
import '../screens/password_reset_email.dart';
import '../screens/registration_screen.dart';
import '../widgets/button.dart';
import '../widgets/google_button.dart';
import '../widgets/input_field.dart';
import '../widgets/link_button.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLoginLoading = false;
  bool _isGoogleLoading = false;
  final TextEditingController _emailController    = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isPasswordVisible = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleLoginSuccess(AuthProvider authProvider) {
    if (authProvider.user?.isVerified == true && authProvider.user!.profileImageUrl != null) {
      SnackbarHelper.showSuccessSnackbar(context, "Login successful!");
      navigateTo(context, const NavigationHome(), clearStack: true);
    } else if (authProvider.user?.isVerified == true && authProvider.user?.profileImageUrl == null) {
      SnackbarHelper.showSuccessSnackbar(context, "YOU MUST PROVIDE YOUR FACIAL DATA FOR PROCEEDING NEXT!");
      navigateTo(context, const RegistrationImage(), clearStack: true);
    } else {
      navigateTo(context, EmailVerification(email: authProvider.user?.email ?? ''), clearStack: true);
    }
  }


  Future<void> _submitForm(AuthProvider authProvider) async {
    setState(() {
      _isLoginLoading = true;
    });

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (!EmailValidators.isValidEmail(email)) {
      SnackbarHelper.showErrorSnackbar(context, "Please enter a valid email address");
      setState(() => _isLoginLoading = false);
      return;
    }

    if (!EmailValidators.hasAllowedDomain(email)) {
      SnackbarHelper.showErrorSnackbar(context, "Please use an email with gmail.com, edu.pk, or .com domain");
      setState(() => _isLoginLoading = false);
      return;
    }

    if (password.isEmpty) {
      SnackbarHelper.showErrorSnackbar(context, "Please enter your password");
      setState(() => _isLoginLoading = false);
      return;
    }

    if (password.length < 6) {
      SnackbarHelper.showErrorSnackbar(context, "Password must be at least 6 characters");
      setState(() => _isLoginLoading = false);
      return;
    }

    final user = User(email: email, username: "", password: password);

    try {
      await authProvider.loginWithEmail(user);
      if (!mounted) return;
      if (authProvider.jwtToken != null) {
        _handleLoginSuccess(authProvider);
      } else if (authProvider.error != null) {
        SnackbarHelper.showErrorSnackbar(context, authProvider.error!);
      }
    } catch (e) {
      if (mounted) {
        SnackbarHelper.showErrorSnackbar(context, authProvider.error ?? 'Login failed');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoginLoading = false);
      }
    }
  }


  Future<void> _handleGoogleSignIn(AuthProvider authProvider) async {
    setState(() => _isGoogleLoading = true);

    try {
      await authProvider.loginWithGoogle();
      if (!mounted) return;

      if (authProvider.jwtToken != null && authProvider.user!.profileImageUrl != null) {
        SnackbarHelper.showSuccessSnackbar(context, "Google Sign-In successful!");
        navigateTo(context, const NavigationHome(), clearStack: true);
      } else if (authProvider.jwtToken != null && authProvider.user!.profileImageUrl == null) {
        SnackbarHelper.showSuccessSnackbar(context, "YOU must provide your facial data for proceeding next!");
        navigateTo(context, const RegistrationImage(), clearStack: true);
      } else if (authProvider.error != null) {
        SnackbarHelper.showErrorSnackbar(context, authProvider.error!);
      }
    } catch (e) {
      if (mounted) {
        SnackbarHelper.showErrorSnackbar(context, authProvider.error ?? 'Google Sign-In failed');
      }
    } finally {
      if (mounted) {
        setState(() => _isGoogleLoading = false);
      }
    }
  }



  void _togglePasswordVisibility() {
    setState(() => _isPasswordVisible = !_isPasswordVisible);
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
            top: size.height * 0.05,
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
              _buildForgotPasswordLink(),
              _buildLoginButton(authProvider),
              _buildSeparator(),
              _buildGoogleButton(authProvider),
              _buildRegisterLink(),
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
          "Welcome Back!",
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 5),
        Text(
          "Enter your credentials to login",
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

  Widget _buildForgotPasswordLink() {
    return Align(
      alignment: Alignment.topRight,
      child: TextButton(
        onPressed: () {
          navigateTo(context, const PasswordResetScreen());
        },
        child: const Text(
          "Forgot password?",
          style: TextStyle(fontSize: 14),
        ),
      ),
    );
  }

  Widget _buildLoginButton(AuthProvider authProvider) {
    return AuthenticationButton(
      text: "Login",
      onPressed: _isLoginLoading ? null : () => _submitForm(authProvider),
      isLoading: _isLoginLoading,
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
      onPressed: _isGoogleLoading ? null : () => _handleGoogleSignIn(authProvider),
      isLoading: _isGoogleLoading,
      text: "Sign in with Google",
      borderRadius: 10,
      padding: const EdgeInsets.symmetric(vertical: 12),
      iconSize: 24,
      spacing: 12,
      fontSize: 16,
      fontWeight: FontWeight.bold,
    );
  }


  Widget _buildRegisterLink() {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Center(
        child: LinkButton(
          desc: "Don't have an account? ",
          text: "Register",
          onPressed: () {
            navigateTo(context, const SignUp());
          },
        ),
      ),
    );
  }
}
