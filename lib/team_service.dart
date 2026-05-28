import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TeamService {
  /// Creates a new user in Firebase Auth AND adds them to Firestore 'users' collection
  /// without logging out the current Admin.
  Future<void> createTeamMember({
    required String email,
    required String password,
    required String name,
    required String role,
    required List<String>  permissions,
  }) async {
    FirebaseApp? tempApp;
    try {
      // 1. Initialize a secondary Firebase App instance
      // We use the options from the default app so it connects to the same project
      tempApp = await Firebase.initializeApp(
        name: 'temporaryRegisterApp', 
        options: Firebase.app().options,
      );

      // 2. Create the user using the secondary app instance
      UserCredential userCredential = await FirebaseAuth.instanceFor(app: tempApp)
          .createUserWithEmailAndPassword(email: email, password: password);

      String uid = userCredential.user!.uid;

      // 3. Write user details to Firestore (Use the MAIN instance here, as it has Admin privs)
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'uid': uid,
        'email': email,
        'displayName': name,
        'role': role,
        'isActive': true,
        'photoURL': '', // Optional: Add a default avatar URL here
        'createdAt': FieldValue.serverTimestamp(),
        'permissions':permissions
      });

      // 4. (Optional) Update the Display Name in Auth as well
      await userCredential.user!.updateDisplayName(name);

    } catch (e) {
      // Propagate error to UI
      throw e; 
    } finally {
      // 5. IMPORTANT: Delete the secondary app instance to clean up
      if (tempApp != null) {
        await tempApp.delete();
      }
    }
  }
}