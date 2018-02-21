TOOL_NAME = extrainst_
extrainst__INSTALL_PATH = /DEBIAN

extrainst__OBJC_FILES = main.mm
extrainst__FRAMEWORKS = UIKit
extrainst__OBJCCFLAGS = -DAPP_ID=\"$(APP_ID)\" -I $(THEOS_PROJECT_DIR)/Common -include $(THEOS_PROJECT_DIR)/Libraries/Common/firmware.h -fvisibility=hidden
extrainst__CODESIGN_FLAGS="-SEntitlements.plist"

ARCHS := armv6 arm64

include $(THEOS)/makefiles/common.mk
include $(THEOS)/makefiles/tool.mk
