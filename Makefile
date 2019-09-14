
install: breath.pl
	echo '#''!'`which perl` > /usr/local/bin/breath
	cat breath.pl >> /usr/local/bin/breath
	chmod +x /usr/local/bin/breath	

uninstall: /usr/local/bin/breath
	rm /usr/local/bin/breath
