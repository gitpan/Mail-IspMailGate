dnl
dnl	File: /etc/mail/sendmail.mc
dnl
dnl     Main sendmail configuration file, fixing various paths and
dnl	other settings. The file is documented in
dnl	/usr/lib/sendmail-cf/README.
dnl
dnl	Do not modify this file unless you really know, what you are
dnl	doing!
dnl
dnl	In case of modifications, run /usr/sbin/ispSendmailRestart
dnl
dnl	See also:	/etc/mail/sendmail.cf
dnl			/etc/mail/aliases
dnl			/etc/mail/access
dnl			/etc/mail/relay-domains
dnl			/etc/mail/mailertable
dnl			/etc/mail/sendmail.cw
dnl
dnl	(All lines beginning with dnl are comments!)
dnl
dnl	File created:	Jochen Wiedmann
dnl			Am Eisteich 9
dnl			72555 Metzingen
dnl			Germany
dnl			
dnl			E-Mail: joe@ispsoft.de
dnl
dnl	Version:	1999-04-02	Jochen Wiedmann
dnl					Initial version
dnl
dnl ########################################################################
dnl
dnl What follows will be added to the top of /etc/mail/sendmail.cf:
dnl
#
#	File: /etc/mail/sendmail.cf
#
#	Main sendmail configuration file, fixing various paths and
#	other settings.
#
#	This file was generated automagically from
#	/etc/mail/sendmail.mc. Don't modify it, instead modify
#	the original!
#
#	See also:	/etc/mail/sendmail.mc
#
#	(All lines beginning with # are comments!)
#

divert(-1)
include(`/usr/lib/sendmail-cf/m4/cf.m4')
define(`confDEF_USER_ID',``8:12'')
define(`confCW_FILE', `/etc/mail/sendmail.cw')
define(`ALIAS_FILE', `/etc/mail/aliases')
OSTYPE(`linux')
undefine(`UUCP_RELAY')
undefine(`BITNET_RELAY')
FEATURE(always_add_domain)
FEATURE(use_cw_file)
FEATURE(local_procmail)
FEATURE(mailertable, hash -o /etc/mail/mailertable)
FEATURE(access_db)
MAILER(procmail)
MAILER(smtp)
MAILER(ispmailgate)

