// lib/data/services/auth_service.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hospital_field_app/core/constants/app_constants.dart';
import 'package:hospital_field_app/data/models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // --- Stream of auth state changes ---
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // --- Get current Firebase user ---
  User? get currentUser => _auth.currentUser;

  /// Sign in with email and password.
  /// Returns [UserModel] on success, throws [FirebaseAuthException] on failure.
  Future<UserModel> signIn({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    final uid = credential.user!.uid;
    return await _getUserModel(uid);
  }

  /// Fetch user model from Firestore.
  Future<UserModel> _getUserModel(String uid) async {
    final doc = await _firestore
        .collection(AppConstants.usersCollection)
        .doc(uid)
        .get();

    if (!doc.exists) {
      throw Exception('User profile not found. Contact administrator.');
    }

    return UserModel.fromFirestore(doc);
  }

  /// Get user model by ID (for manager to look up field staff).
  Future<UserModel?> getUserById(String userId) async {
    try {
      final doc = await _firestore
          .collection(AppConstants.usersCollection)
          .doc(userId)
          .get();
      if (!doc.exists) return null;
      return UserModel.fromFirestore(doc);
    } catch (_) {
      return null;
    }
  }

  /// Fetch current user's profile from Firestore.
  Future<UserModel?> getCurrentUserModel() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    try {
      return await _getUserModel(user.uid);
    } catch (_) {
      return null;
    }
  }

  /// Sign out.
  Future<void> signOut() async {
    await _auth.signOut();
  }

  /// Create user (for admin/seeding purposes).
  Future<UserModel> createUser({
    required String email,
    required String password,
    required String name,
    required String role,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    final uid = credential.user!.uid;
    final userModel = UserModel(
      id: uid,
      name: name,
      email: email.trim(),
      role: role,
      createdAt: DateTime.now(),
    );

    await _firestore
        .collection(AppConstants.usersCollection)
        .doc(uid)
        .set(userModel.toMap());

    return userModel;
  }
}
