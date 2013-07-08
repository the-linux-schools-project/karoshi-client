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

Some Karoshi utilities need to be symlinked into /usr/bin from their /opt/karoshi/linuxclientsetup/utilities location, to allow desktop icons to correctly reference them and be used system-wide.

See **install/link-list** for a list of files that are linked into various places
