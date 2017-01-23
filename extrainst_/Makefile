TOOL_NAME = extrainst_
extrainst__INSTALL_PATH = /DEBIAN

extrainst__OBJC_FILES = main.mm
extrainst__FRAMEWORKS = UIKit
extrainst__OBJCCFLAGS = -DAPP_ID=\"$(APP_ID)\" -I $(THEOS_PROJECT_DIR)/Common -include $(THEOS_PROJECT_DIR)/Libraries/Common/firmware.h -fvisibility=hidden

ARCHS := armv6

include ../theos/makefiles/common.mk
include ../theos/makefiles/tool.mk
