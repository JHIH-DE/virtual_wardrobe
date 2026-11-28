import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../widgets/cms_scope.dart';
import 'issues_page.dart';
import 'items_page.dart';
import 'users_page.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  Future<void> _signOut() async {
    CmsScope.read(context).client.signOut();
    await GoogleSignIn.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _index,
            onDestinationSelected: (i) => setState(() => _index = i),
            labelType: NavigationRailLabelType.all,
            leading: const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'Uwearis\n雜誌後台',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            trailing: Expanded(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: IconButton(
                    tooltip: '登出',
                    icon: const Icon(Icons.logout),
                    onPressed: _signOut,
                  ),
                ),
              ),
            ),
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.menu_book_outlined),
                label: Text('期數與文章'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.checkroom_outlined),
                label: Text('單品'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.people_outline),
                label: Text('使用者'),
              ),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: IndexedStack(
              index: _index,
              children: const [IssuesPage(), ItemsPage(), UsersPage()],
            ),
          ),
        ],
      ),
    );
  }
}
