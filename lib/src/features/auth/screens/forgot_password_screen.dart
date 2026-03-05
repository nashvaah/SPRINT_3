import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:carenow/l10n/app_localizations.dart';
import '../services/auth_provider.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  bool _isSent = false;
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _handleReset() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() => _errorMessage = "Please enter an email address.");
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await Provider.of<AuthProvider>(context, listen: false).sendPasswordResetEmail(email);
      if (!mounted) return;
      setState(() {
        _isSent = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password reset link has been sent to your email.'), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.resetPassword)),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: _isSent
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                   const Icon(Icons.check_circle, color: Colors.green, size: 64),
                   const SizedBox(height: 16),
                   Text(l10n.checkEmail, style: Theme.of(context).textTheme.headlineSmall),
                   const SizedBox(height: 8),
                   Text(l10n.sentRecoveryInstructions, textAlign: TextAlign.center),
                   const SizedBox(height: 24),
                   ElevatedButton(onPressed: () => Navigator.pop(context), child: Text(l10n.backToLogin)),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(l10n.enterEmailForReset),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _emailController,
                    decoration: InputDecoration(
                        labelText: l10n.emailAddress, 
                        prefixIcon: const Icon(Icons.email),
                        errorText: _errorMessage,
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (_isLoading)
                    const Center(child: CircularProgressIndicator())
                  else
                    ElevatedButton(
                      onPressed: _handleReset,
                      child: Text(l10n.sendResetLink),
                    ),
                ],
              ),
      ),
    );
  }
}
