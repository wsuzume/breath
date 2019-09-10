
install: breath.pl
	echo '#''!'`which perl` > breath
	cat breath.pl >> breath
	chmod +x breath	

uninstall: breath
	rm breath
