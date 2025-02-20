import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Case Management App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: AuthScreen(),
    );
  }
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  AuthScreenState createState() => AuthScreenState();
}

class AuthScreenState extends State<AuthScreen>{
  final _auth = FirebaseAuth.instance;
  bool _isLogin = true;
  String _email = '';
  String _password = '';
  String _username = '';

  void _submitAuthForm() async {
    UserCredential authResult;
    try {
      if (_isLogin) {
        authResult = await _auth.signInWithEmailAndPassword(
          email: _email,
          password: _password,
        );
      } else {
        authResult = await _auth.createUserWithEmailAndPassword(
          email: _email,
          password: _password,
        );
        await FirebaseFirestore.instance
            .collection('users')
            .doc(authResult.user!.uid)
            .set({
          'username': _username,
          'email': _email,
        });
      }
    } catch (err) {
      debugPrint(err.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Authenticate'),
      ),
      body: Center(
        child: Card(
          margin: EdgeInsets.all(20),
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!_isLogin)
                  TextField(
                    key: ValueKey('username'),
                    decoration: InputDecoration(labelText: 'Username'),
                    onChanged: (value) {
                      setState(() {
                        _username = value;
                      });
                    },
                  ),
                TextField(
                  key: ValueKey('email'),
                  decoration: InputDecoration(labelText: 'Email'),
                  onChanged: (value) {
                    setState(() {
                      _email = value;
                    });
                  },
                ),
                TextField(
                  key: ValueKey('password'),
                  decoration: InputDecoration(labelText: 'Password'),
                  obscureText: true,
                  onChanged: (value) {
                    setState(() {
                      _password = value;
                    });
                  },
                ),
                SizedBox(height: 12),
                ElevatedButton(
                  onPressed: _submitAuthForm,
                  child: Text(_isLogin ? 'Login' : 'Signup'),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _isLogin = !_isLogin;
                    });
                  },
                  child: Text(_isLogin
                      ? 'Create new account'
                      : 'I already have an account'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}



class CaseManagementScreen extends StatelessWidget {
  final _firestore = FirebaseFirestore.instance;

      CaseManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Case Management'),
        actions: [
          IconButton(
            icon: Icon(Icons.add),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => AddEditCaseScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder(
        stream: _firestore.collection('cases').snapshots(),
        builder: (ctx, AsyncSnapshot<QuerySnapshot> caseSnapshot) {
          if (caseSnapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          final caseDocs = caseSnapshot.data!.docs;
          return ListView.builder(
            itemCount: caseDocs.length,
            itemBuilder: (ctx, index) => ListTile(
              title: Text(caseDocs[index]['title']),
              subtitle: Text(caseDocs[index]['description']),
              trailing: IconButton(
                icon: Icon(Icons.delete),
                onPressed: () {
                  _firestore.collection('cases').doc(caseDocs[index].id).delete();
                },
              ),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => AddEditCaseScreen(
                      caseId: caseDocs[index].id,
                      caseData: caseDocs[index],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class AddEditCaseScreen extends StatefulWidget {
  final String? caseId;
  final DocumentSnapshot? caseData;

   const AddEditCaseScreen({super.key, this.caseId, this.caseData});
  
  @override
  AddEditCaseScreenState createState() => AddEditCaseScreenState();
}

class AddEditCaseScreenState extends State<AddEditCaseScreen> {
  final _formKey = GlobalKey<FormState>();
  String _title = '';
  String _description = '';
  File? _image;

  void _pickImage() async {
    final pickedImage = await ImagePicker().pickImage(
      source: ImageSource.gallery,
    );
    if (pickedImage != null) {
      setState(() {
        _image = File(pickedImage.path);
      });
    }
  }

  void _submitForm() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      if (widget.caseId == null) {
        final ref = FirebaseStorage.instance
            .ref()
            .child('case_images')
            .child('${DateTime.now().toIso8601String()}.jpg');
        await ref.putFile(_image!);
        final url = await ref.getDownloadURL();
        await FirebaseFirestore.instance.collection('cases').add({
          'title': _title,
          'description': _description,
          'imageUrl': url,
        });
      } else {
        await FirebaseFirestore.instance
            .collection('cases')
            .doc(widget.caseId)
            .update({
          'title': _title,
          'description': _description,
        });
      }
      if (mounted) {
          Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.caseId == null ? 'Add Case' : 'Edit Case'),
      ),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                initialValue: widget.caseData != null ? widget.caseData!['title'] : '',
                decoration: InputDecoration(labelText: 'Title'),
                validator: (value) {
                  if (value!.isEmpty) {
                    return 'Please enter a title';
                  }
                  return null;
                },
                onSaved: (value) {
                  _title = value!;
                },
              ),
              TextFormField(
                initialValue: widget.caseData != null ? widget.caseData!['description'] : '',
                decoration: InputDecoration(labelText: 'Description'),
                validator: (value) {
                  if (value!.isEmpty) {
                    return 'Please enter a description';
                  }
                  return null;
                },
                onSaved: (value) {
                  _description = value!;
                },
              ),
              SizedBox(height: 10),
              if (_image != null)
                Image.file(
                  _image!,
                  height: 100,
                  width: 100,
                  fit: BoxFit.cover,
                ),
              TextButton.icon(
                icon: Icon(Icons.image),
                label: Text('Add Image'),
                onPressed: _pickImage,
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _submitForm,
                child: Text(widget.caseId == null ? 'Add Case' : 'Update Case'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ClientManagementScreen extends StatelessWidget {
  final _firestore = FirebaseFirestore.instance;
 ClientManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Client Management'),
        actions: [
          IconButton(
            icon: Icon(Icons.add),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => AddEditClientScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder(
        stream: _firestore.collection('clients').snapshots(),
        builder: (ctx, AsyncSnapshot<QuerySnapshot> clientSnapshot) {
          if (clientSnapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          final clientDocs = clientSnapshot.data!.docs;
          return ListView.builder(
            itemCount: clientDocs.length,
            itemBuilder: (ctx, index) => ListTile(
              title: Text(clientDocs[index]['name']),
              subtitle: Text(clientDocs[index]['email']),
              trailing: IconButton(
                icon: Icon(Icons.delete),
                onPressed: () {
                  _firestore.collection('clients').doc(clientDocs[index].id).delete();
                },
              ),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => AddEditClientScreen(
                      clientId: clientDocs[index].id,
                      clientData: clientDocs[index],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class AddEditClientScreen extends StatefulWidget {
  final String? clientId;
  final DocumentSnapshot? clientData;

  const AddEditClientScreen({super.key, this.clientId, this.clientData});

  @override
  AddEditClientScreenState createState() => AddEditClientScreenState();
}

class AddEditClientScreenState extends State<AddEditClientScreen> {
  final _formKey = GlobalKey<FormState>();
  late String _name = '';
  late String _email = '';

  void _submitForm() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      if (widget.clientId == null) {
        await FirebaseFirestore.instance.collection('clients').add({
          'name': _name,
          'email': _email,
        });
      } else {
        await FirebaseFirestore.instance
            .collection('clients')
            .doc(widget.clientId)
            .update({
          'name': _name,
          'email': _email,
        });
      }
      if (mounted) {
          Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.clientId == null ? 'Add Client' : 'Edit Client'),
      ),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                initialValue: widget.clientData != null ? widget.clientData!['name'] : '',
                decoration: InputDecoration(labelText: 'Name'),
                validator: (value) {
                  if (value!.isEmpty) {
                    return 'Please enter a name';
                  }
                  return null;
                },
                onSaved: (value) {
                  _name = value!;
                },
              ),
              TextFormField(
                initialValue: widget.clientData != null ? widget.clientData!['email'] : '',
                decoration: InputDecoration(labelText: 'Email'),
                validator: (value) {
                  if (value!.isEmpty) {
                    return 'Please enter an email';
                  }
                  return null;
                },
                onSaved: (value) {
                  _email = value!;
                },
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _submitForm,
                child: Text(widget.clientId == null ? 'Add Client' : 'Update Client'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}