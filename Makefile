SUBPROJECTS ?= Application Extension/Loader Extension/3.0 Extension/4.0 extrainst_

export APP_ID := com.chpwn.iconsupport
export TARGET ?= iphone:8.4:3.0

include $(THEOS)/makefiles/common.mk
include $(THEOS)/makefiles/aggregate.mk

distclean: clean
	- rm -f $(THEOS_PROJECT_DIR)/$(APP_ID)*.deb
	- rm -f $(THEOS_PROJECT_DIR)/.theos/packages/*
