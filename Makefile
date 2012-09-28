SUBPROJECTS = Extension PostInstall

export APP_ID = com.chpwn.iconsupport

include theos/makefiles/common.mk
include theos/makefiles/aggregate.mk

distclean: clean
	- rm -f $(THEOS_PROJECT_DIR)/$(APP_ID)*.deb
	- rm -f $(THEOS_PROJECT_DIR)/.theos/packages/*
