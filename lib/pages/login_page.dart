import 'package:flutter/material.dart';
import 'package:flutter_chat_app/constants/app_constants.dart';
import 'package:flutter_chat_app/constants/color_constants.dart';
import 'package:flutter_chat_app/pages/pages.dart';
import 'package:flutter_chat_app/providers/auth_provider.dart';
import 'package:flutter_chat_app/widgets/widgets.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:provider/provider.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  LoginPageState createState() => LoginPageState();
}

class LoginPageState extends State<LoginPage> {
  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    switch (authProvider.status) {
      case Status.authenticateError:
        Fluttertoast.showToast(msg: "Sign in fail");
        break;
      case Status.authenticateCanceled:
        Fluttertoast.showToast(msg: "Sign in canceled");
        break;
      case Status.authenticated:
        Fluttertoast.showToast(msg: "Sign in success");
        break;
      default:
        break;
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          AppConstants.loginTitle,
          style: TextStyle(color: ColorConstants.primaryColor),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          Center(
            child: TextButton(
              onPressed: () async {
                authProvider.handleSignIn().then((isSuccess) {
                  if (isSuccess) {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const HomePage(),
                      ),
                    );
                  }
                }).catchError((error, stackTrace) {
                  Fluttertoast.showToast(msg: error.toString());
                  authProvider.handleException();
                });
              },
              style: ButtonStyle(
                backgroundColor: MaterialStateProperty.resolveWith<Color>(
                  (Set<MaterialState> states) {
                    if (states.contains(MaterialState.pressed)) {
                      return ColorConstants.themeColor;
                    }
                    return ColorConstants.primaryColor;
                  },
                ),
                splashFactory: NoSplash.splashFactory,
                padding: MaterialStateProperty.all<EdgeInsets>(
                  const EdgeInsets.fromLTRB(30, 15, 30, 15),
                ),
              ),
              child: const Text(
                'Sign in with Google',
                style: TextStyle(fontSize: 16, color: Colors.white),
              ),
            ),
          ),
          // Loading
          Positioned(
            child: authProvider.status == Status.authenticating
                ? const LoadingView()
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}
