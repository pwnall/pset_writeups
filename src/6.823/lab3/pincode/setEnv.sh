#!/bin/sh

if [ "$#" -gt 1 ]; then
  echo "More than 1 argument entered" && exit 1
fi

pkgs=""

if [ "$#" -eq 0 ]; then
  echo "Please enter environment setting linerva or vlsi"
  read pkgs
fi

if [ -z "$pkgs" ]; then
  for file in "$@"
  do
	if [ $file == "linerva" ]; then
		sed -e "s/bpredictor/bpredictor.so/g" lab3test.pl>temp_lab3test.pl
		cp -r temp_lab3test.pl  lab3test.pl
		sed -e "s/bpredictor.so.so/bpredictor.so/g" lab3test.pl>temp_lab3test.pl
		sed -e "s/drivetests.pl/drivetests2.pl/g" temp_lab3test.pl> lab3test.pl
		rm -rf temp_lab3test.pl
		sed -e "s/MIT6823\_HOME*)\/make/MIT6823\_HOME)\/Pin2009\/source\/tools\/make/g" Makefile>temp_Makefile
		cp -r temp_Makefile Makefile
		rm -rf temp_Makefile		
	else
		sed -e "s/bpredictor.so/bpredictor/g" lab3test.pl>temp_lab3test.pl
		sed -e "s/drivetests2.pl/drivetests.pl/g" temp_lab3test.pl> lab3test.pl
		rm -rf temp_lab3test.pl
		sed -e "s/MIT6823\_HOME*)\/Pin2009\/source\/tools\/make/MIT6823\_HOME)\/make/g" Makefile>temp_Makefile
		cp -r temp_Makefile Makefile
		rm -rf temp_Makefile	
	fi
	
  done
else
  for file in "$pkgs"
  do
	if [ $file == "linerva" ]; then
		sed -e "s/bpredictor/bpredictor.so/g" lab3test.pl>temp_lab3test.pl
		cp -r temp_lab3test.pl  lab3test.pl
		sed -e "s/bpredictor.so.so/bpredictor.so/g" lab3test.pl>temp_lab3test.pl
		sed -e "s/drivetests.pl/drivetests2.pl/g" temp_lab3test.pl> lab3test.pl
		rm -rf temp_lab3test.pl
		sed -e "s/MIT6823\_HOME*)\/make/MIT6823\_HOME)\/Pin2009\/source\/tools\/make/g" Makefile>temp_Makefile
		cp -r temp_Makefile Makefile
		rm -rf temp_Makefile		
	else
		sed -e "s/bpredictor.so/bpredictor/g" lab3test.pl>temp_lab3test.pl
		sed -e "s/drivetests2.pl/drivetests.pl/g" temp_lab3test.pl> lab3test.pl
		rm -rf temp_lab3test.pl
		sed -e "s/MIT6823\_HOME*)\/Pin2009\/source\/tools\/make/MIT6823\_HOME)\/make/g" Makefile>temp_Makefile
		cp -r temp_Makefile Makefile
		rm -rf temp_Makefile	
	fi
  done
fi

exit 0

