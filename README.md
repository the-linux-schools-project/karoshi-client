# Karoshi Client

*Repository for storing scripts and configuration files for Karoshi Client*

- **Maintainer:** Robin McCorkell &lt;rmccorkell@karoshi.org.uk&gt;
- **Website:** http://linuxgfx.co.uk/
- **Documentation:** http://www.linuxgfx.co.uk/karoshi/documentation/wiki/
- **Current stable version:** 3.0

**ISO Syntax:** karoshi-client-&lt;version&gt;-&lt;arch&gt;.iso

**Title Syntax:** Karoshi Client &lt;version&gt;-&lt;arch&gt;

## File list

- **install.sh** is a script to perform a conversion from stock Ubuntu to Karoshi
- **LICENCE** contains a copy of the AGPL v3
- **README.md** is this file
- **configuration/** contains the system configuration
- **install/** contains files needed for an installation
- **linuxclientsetup/** contains the main client-side scripts
- **skel/** contains configuration files for the client, usually placed on the server
- other files are assorted temporary configuration files

## Packages

See **install/install-list** for a list of packages installed as part of a Karoshi installation

See **install/rubygem-list** for a list of Ruby gems installed as part of a Karoshi installation

See **install/remove-list** for a list of packages that are removed as part of a Karoshi installation

## Symlinks

Some Karoshi utilities need to be symlinked into /usr/bin from their /opt/karoshi/linuxclientsetup/utilities location,
to allow desktop icons to correctly reference them and be used system-wide. Also, background images are linked from
/opt/karoshi/linuxclientsetup/images and /var/lib/karoshi/images to /usr/share/backgrounds using the update-alternatives
system.

See **install/alternatives-list** for a list of files that are linked into various places
