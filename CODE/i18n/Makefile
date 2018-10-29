all: locales/fr_FR/LC_MESSAGES/webobs.mo locales/en_US/LC_MESSAGES/webobs.mo
locales/%/LC_MESSAGES/webobs.mo: %.po Makefile
	msgfmt -o $@ $<
