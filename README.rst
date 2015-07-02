Connecting to XTAG devices over a network connection using xtcp
===============================================================

.. appnote:: AN01031

.. version:: 1.0.0


Summary
-------

XMOS XTAG is a powerful interface for debugging XMOS realtime applications,
allowing the attachment of the xgdb debugging application.

By using the xtcp library we can bridge this interface over Ethernet, rather
than using the traditional USB stack. This allows remote debugging of XMOS
hardware devices over a network conenction.

Required tools and libraries
............................

* xTIMEcomposer Tools - Version 13.1.0
* XMOS Ethernet/TCP xSOFTip component - Version 3.2.1rc1
* XMOS sc_xtag Libraries from GitHub - Head @ f60fa1
