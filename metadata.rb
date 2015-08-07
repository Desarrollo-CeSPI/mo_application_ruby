name             'mo_application_ruby'
maintainer       'Christian A. Rodriguez & Leandro Di Tommaso'
maintainer_email 'chrodriguez@gmail.com leandro.ditommaso@mikroways.net'
license          'All rights reserved'
description      'Installs/Configures mo_application_ruby'
long_description 'Installs/Configures mo_application_ruby'
version          '1.1.13'

depends         'mo_application',     "~> 1.1.17"
depends         'java',               "~> 1.29.0"
depends         'sudo',               "~> 2.7.1"
depends         'rbenv',              '~>1.7.1'

supports "ubuntu", ">= 14.04"
