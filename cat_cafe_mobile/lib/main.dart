// ignore_for_file: prefer_const_constructors

import 'package:cat_cafe_mobile/pages/home_page.dart';
import 'package:close_range_util/close_range_util.dart';
import 'package:flutter/material.dart';

void main() async {
  
  await CREnv.init();
  await CRSave.init();
  await CRDatabase.init(
    url: CREnv["SUPABASE_URL"]!,
    anonKey: CREnv["SUPABASE_ANON_KEY"]!,
  );

  // Debug.setActive(false);

  runApp(Entry(home: CRLoginPage(homePage: HomePage(),
    
    devLogins: const [
          ["Savannah", "5416450209", "123456"],
          ["Mike", "4142163487", "123456"],
    ],
  ), title: 'Cat Cafe App',

  ));
}
