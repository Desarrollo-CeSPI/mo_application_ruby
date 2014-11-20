# mo_application_ruby-cookbook

LWRP that extends mo_application for Ruby applications

## Usage

Just include this recipe as a dependency and use provided LWRPs:

### Resource `mo_application_ruby`

Is the specialized version of mo_application for Ruby apps doing the following
tasks:

* Creates an application directory
* Creates log directories for nginx services inside application's directory
* Deploys application, but if **deploy** parameter is set to false, it creates an empty applications
  directory
* Creates link inside application's user home directory pointing to
  application's directory & logs
* Configures nginx site

#### Relevant parameters are:

* **path**: root applications chrooted directory
* **nginx_config**: hash to be merged with default values. This values are defined as a hash of:
  * **key** is vhost file name, it will namespaced with mo_application name attribute
  * **value** is a hash of nginx options. Most values can be overwritten. Custom options are:
    * **relative_document_root:** as deploy resource will create a current symlink, then specified path
      for this option must be a relative project path: by default we asume it is `web/`

If applications document root includes a file named `mantenimiento.html` it will
be served as first resource in any cases

## Recipes

### Recipe `mo_application_ruby::install`

Installs all requirements

