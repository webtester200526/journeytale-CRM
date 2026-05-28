import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crmx/team_service.dart'; 
import 'package:flutter/material.dart';

// 1. Master List of Pages
const Map<String, String> _availablePages = {
  'orders': 'Orders',
  'calendar': 'Calendar',
  'finance': 'Finance',
  'destinations': 'Destinations',
  'team': 'Team Management',
  'services': 'Services Catalog',
  'customers': 'Customer Database',
  'forex': 'Forex',
  'tourguides': 'Tour Guide Profiles',
  'transport':'Transport Providers',
  'hotels':'Manage Hotels'
};

class TeamManagerPage extends StatelessWidget {
  const TeamManagerPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- HEADER ---
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Team Management", style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
                        const SizedBox(height: 8),
                        Text("Manage access levels and permissions for your staff.", style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                      ],
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _showAddUserDialog(context),
                      
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text("Add Member"),
                    )
                  ],
                ),
                
                const SizedBox(height: 40),

                // --- DATA TABLE ---
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))
                      ]
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: const _TeamListStream(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showAddUserDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const _AddUserDialog(),
    );
  }
}

// --- ADD USER DIALOG (UPDATED WITH CHECKLIST) ---

class _AddUserDialog extends StatefulWidget {
  const _AddUserDialog({super.key});

  @override
  State<_AddUserDialog> createState() => _AddUserDialogState();
}

class _AddUserDialogState extends State<_AddUserDialog> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passController = TextEditingController();
  
  // Changed from String _role to List of permissions
  List<String> _selectedPermissions = []; 
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passController.dispose();
    super.dispose();
  }

  void _toggleSelectAll() {
    setState(() {
      if (_selectedPermissions.length == _availablePages.length) {
        _selectedPermissions.clear();
      } else {
        _selectedPermissions = List.from(_availablePages.keys);
      }
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // NOTE: Ensure your TeamService.createTeamMember accepts 'permissions' parameter.
      // If it doesn't, you need to update TeamService or update the Firestore doc manually immediately after creation.
      await TeamService().createTeamMember(
        email: _emailController.text.trim(),
        password: _passController.text.trim(),
        name: _nameController.text.trim(),
        role: 'custom', // We just pass a placeholder role since we use permissions now
        permissions: _selectedPermissions, // Pass the list
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("User created successfully"), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: ${e.toString()}"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: const Text("Add New Team Member"),
      content: SizedBox(
        width: 400,
        height: 550, // Increased height for checklist
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Basic Info Fields
              TextFormField(
                controller: _nameController,
                decoration: _inputDecoration("Full Name"),
                validator: (val) => val!.isEmpty ? "Required" : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                decoration: _inputDecoration("Email Address"),
                validator: (val) => !val!.contains('@') ? "Invalid Email" : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passController,
                decoration: _inputDecoration("Temporary Password"),
                obscureText: true,
                validator: (val) => val!.length < 6 ? "Min 6 characters" : null,
              ),
              
              const SizedBox(height: 24),
              
              // 2. Permissions Header & Toggle
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Access Permissions", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  TextButton(
                    onPressed: _toggleSelectAll,
                    style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(50, 30)),
                    child: Text(
                      _selectedPermissions.length == _availablePages.length ? "Deselect All" : "Select All", 
                      style: const TextStyle(fontSize: 12)
                    ),
                  )
                ],
              ),
              const Divider(height: 1),

              // 3. Checklist
              Expanded(
                child: ListView(
                  children: _availablePages.entries.map((entry) {
                    final pageId = entry.key;
                    final pageTitle = entry.value;
                    final bool isChecked = _selectedPermissions.contains(pageId);

                    return CheckboxListTile(
                      title: Text(pageTitle, style: const TextStyle(fontSize: 14)),
                      value: isChecked,
                      activeColor: Colors.black,
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      onChanged: (bool? value) {
                        setState(() {
                          if (value == true) {
                            _selectedPermissions.add(pageId);
                          } else {
                            _selectedPermissions.remove(pageId);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _submit,
         
          child: _isLoading 
            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : const Text("Create User"),
        )
      ],
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      isDense: true,
    );
  }
}

// --- TEAM LIST ---

class _TeamListStream extends StatelessWidget {
  const _TeamListStream({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').orderBy('displayName').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text("Something went wrong", style: TextStyle(color: Colors.red[400])));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data!.docs;

        return SingleChildScrollView(
          child: DataTable(
            headingRowHeight: 60,
            dataRowMinHeight: 70,
            dataRowMaxHeight: 70,
            columnSpacing: 24,
            horizontalMargin: 32,
            columns: [
              DataColumn(label: Text("USER", style: _headerStyle())),
              DataColumn(label: Text("ACCESS COUNT", style: _headerStyle())),
              DataColumn(label: Text("STATUS", style: _headerStyle())),
              DataColumn(label: Text("ACTIONS", style: _headerStyle())),
            ],
            rows: docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final String uid = doc.id;
              final String name = data['displayName'] ?? data['email'] ?? 'Unknown';
              final String email = data['email'] ?? '';
              final String photoUrl = data['photoURL'] ?? '';
              final bool isActive = data['isActive'] ?? true;
              
              // Read permissions array
              final List<dynamic> permissions = data['permissions'] ?? [];

              return DataRow(
                cells: [
                  // 1. User Info
                  DataCell(
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: Colors.grey[200],
                          backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                          child: photoUrl.isEmpty ? Text(name[0].toUpperCase(), style: const TextStyle(color: Colors.black)) : null,
                        ),
                        const SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                            if(email.isNotEmpty)
                              Text(email, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                          ],
                        )
                      ],
                    )
                  ),
                  
                  // 2. Permission Count Badge
                  DataCell(_PermissionCountBadge(count: permissions.length, total: _availablePages.length)),

                  // 3. Status
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: isActive ? Colors.green : Colors.grey)),
                        const SizedBox(width: 8),
                        Text(isActive ? "Active" : "Inactive", style: const TextStyle(fontSize: 13)),
                      ],
                    )
                  ),

                  // 4. Actions
                  DataCell(
                    IconButton(
                      icon: const Icon(Icons.settings_outlined, size: 20, color: Colors.grey),
                      onPressed: () => _showEditPermissionDialog(context, uid, name, permissions),
                      tooltip: "Edit Permissions",
                    )
                  ),
                ],
              );
            }).toList(),
          ),
        );
      },
    );
  }

  TextStyle _headerStyle() {
    return TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey[400], letterSpacing: 1.0);
  }

  // --- EDIT PERMISSIONS DIALOG ---
  void _showEditPermissionDialog(BuildContext context, String uid, String name, List<dynamic> currentPermissions) {
    List<String> selectedPermissions = List<String>.from(currentPermissions);
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            
            void toggleAll() {
              setState(() {
                if (selectedPermissions.length == _availablePages.length) {
                  selectedPermissions.clear();
                } else {
                  selectedPermissions = List.from(_availablePages.keys);
                }
              });
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              title: Text("Edit Access for $name"),
              content: SizedBox(
                width: 400,
                height: 450,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Select allowed pages:", style: TextStyle(fontSize: 13, color: Colors.grey)),
                        TextButton(
                          onPressed: toggleAll, 
                          child: Text(selectedPermissions.length == _availablePages.length ? "Deselect All" : "Select All", style: const TextStyle(fontSize: 12))
                        )
                      ],
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: ListView(
                        children: _availablePages.entries.map((entry) {
                          final pageId = entry.key;
                          final pageTitle = entry.value;
                          final bool isChecked = selectedPermissions.contains(pageId);

                          return CheckboxListTile(
                            title: Text(pageTitle),
                            value: isChecked,
                            activeColor: Colors.black,
                            contentPadding: EdgeInsets.zero,
                            onChanged: (bool? value) {
                              setState(() {
                                if (value == true) {
                                  selectedPermissions.add(pageId);
                                } else {
                                  selectedPermissions.remove(pageId);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  onPressed: isLoading ? null : () async {
                    setState(() => isLoading = true);
                    try {
                      await FirebaseFirestore.instance.collection('users').doc(uid).update({
                        'permissions': selectedPermissions,
                        'lastUpdated': FieldValue.serverTimestamp(),
                      });
                      
                      if(context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Permissions updated successfully")));
                      }
                    } catch (e) {
                      setState(() => isLoading = false);
                      if(context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
                      }
                    }
                  },
                 
                  child: isLoading 
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                    : const Text("Save Access"),
                )
              ],
            );
          }
        );
      },
    );
  }
}

// --- HELPER WIDGETS ---

class _PermissionCountBadge extends StatelessWidget {
  final int count;
  final int total;
  const _PermissionCountBadge({required this.count, required this.total});

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color text;
    String label;

    if (count == total) {
      bg = const Color(0xFFDCFCE7); // Green
      text = const Color(0xFF15803D);
      label = "Full Access";
    } else if (count == 0) {
      bg = const Color(0xFFFEE2E2); // Red
      text = const Color(0xFFB91C1C);
      label = "No Access";
    } else {
      bg = const Color(0xFFDBEAFE); // Blue
      text = const Color(0xFF1D4ED8);
      label = "$count / $total Pages";
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: bg.withOpacity(0.5))
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(color: text, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.5),
      ),
    );
  }
}