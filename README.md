# Karoshi Client

*Repository for storing scripts and configuration files for Karoshi Client*

- **Maintainer:** Robin McCorkell &lt;rmccorkell@karoshi.org.uk&gt;
- **Website:** http://linuxgfx.co.uk/
- **Documentation:** http://www.linuxgfx.co.uk/karoshi/documentation/wiki/
- **Current stable version:** 2.0
- **Current dev version:** 2.2_rc8

**ISO Syntax:** karoshi-client-&lt;version&gt;-&lt;arch&gt;.iso

**Title Syntax:** Karoshi Client &lt;version&gt;-&lt;arch&gt;

## File list

- **CHECKLIST.md** is a short guide for creating a remaster
- **README.md** is this file
- **configuration/** contains the system configuration
- **linuxclientsetup/** contains the main client-side scripts
- **skel/** contains configuration files for the client, usually placed on the server
- other files are assorted temporary configuration files

## Packages

See **install/install-list** for a list of packages that are part of a Karoshi installation

See **install/remove-list** for a list of packages that are removed as part of a Karoshi installation

## Symlinks

Some Karoshi utilities need to be symlinked to karoshi-run-script in /usr/bin so that they can be run using the PATH variable:

- ln -s karoshi-run-script /usr/bin/karoshi-set-local-password
- ln -s karoshi-run-script /usr/bin/karoshi-set-location
- ln -s karoshi-run-script /usr/bin/karoshi-set-network
- ln -s karoshi-run-script /usr/bin/karoshi-setup
- ln -s karoshi-run-script /usr/bin/karoshi-manage-flags
- ln -s karoshi-run-script /usr/bin/karoshi-virtualbox-mkdir
- ln -s karoshi-run-script /usr/bin/karoshi-pam-wrapper
