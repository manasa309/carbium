import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthProvider extends ChangeNotifier {
  User? _currentUser;
  String? _authError;
  bool _isAuthenticated = false;
  bool _isLoading = false;

  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;
  User? get currentUser => _currentUser;
  String? get authError => _authError;

  AuthProvider() {
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      _currentUser = user;
      _isAuthenticated = user != null;
      notifyListeners();
    });
  }

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _authError = null;
    notifyListeners();

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      _isLoading = false;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _authError = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _authError = 'An error occurred: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> signup(String name, String email, String password) async {
    _isLoading = true;
    _authError = null;
    notifyListeners();

    try {
      UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      await userCredential.user?.updateDisplayName(name);
      
      _isLoading = false;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      debugPrint("FirebaseAuthException: ${e.code} - ${e.message}");
      _authError = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      debugPrint("Signup Error: $e");
      _authError = 'Signup failed: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    await FirebaseAuth.instance.signOut();
    notifyListeners();
  }

  Future<void> resetPassword(String email) async {
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw Exception(e.message);
    }
  }

  Future<void> resetApp() async {
    // Not applicable for Firebase, but keeping method signature to avoid breaking changes immediately
    await logout();
  }
}
