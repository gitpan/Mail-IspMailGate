divert(-1)
include(`/usr/lib/sendmail-cf/m4/cf.m4')
OSTYPE(`linux')
undefine(`UUCP_RELAY')
undefine(`BITNET_RELAY')
define(`ISPMAILGATE_MAILER_PATH', `/usr/local/sbin/ispMailGate')
define(`ISPMAILGATE_MAILER_FLAGS', `gmDFMu')
define(`ISPMAILGATE_MAILER_ARGS', `ispMailGate -f $f $u')
define(`confDEF_USER_ID',``8:12'')
define(`SMART_HOST',`192.168.1.1')
FEATURE(mailertable, `hash -o /etc/mail/mailertable')
FEATURE(virtusertable, `hash -o /etc/mail/virtusertable')
FEATURE(redirect)
FEATURE(always_add_domain)
FEATURE(use_cw_file)
FEATURE(local_procmail)
MAILER(procmail)
MAILER(smtp)

MAILER_DEFINITIONS
##################################################
###   IspMailGate Mailer specification         ###
##################################################

Mispmailgate, P=ISPMAILGATE_MAILER_PATH, F=ISPMAILGATE_MAILER_FLAGS,
	S=11/31, R=21/31, T=DNS/RFC822/X-Unix, A=ISPMAILGATE_MAILER_ARGS

LOCAL_CONFIG
KIMGR hash -o /etc/mail/ispMailGateRecipients
CPISPMAILGATE

LOCAL_RULE_0
# Make "user < @ host >" to "<user @ host > user < @ host . >"
R$* < @ $+ > $*			$: < $1 @ $2 > $1 < @ $2 > $3
# At this point we might have "< user @ host . > user < @ host . >"
# Remove the dot from the host part, if any.
R< $+ . > $* < $+ > $*		$: < $1 > $2 < $3 > $4

# Is "user@host" in /etc/mail/ispMailGateRecipients?
R< $* @ $+ > $* < $+ > $*
		$: < $1 @ $2 $(IMGR $1 @ $2 $: $) > $3 < $4 > $5
# Is "@host" in /etc/mail/ispMailGateRecipients?
R< $* @ $+ > $* < $+ > $*
		$: < $1 @ $2 $(IMGR @ $2 $: $) > $3 < $4 > $5
# Is "host" = "@any.domain" with "domain" in /etc/mail/ispMailGateRecipients?
R< $* @ $+ . $+ > $* < $+ > $*
		$: < $1 @ $2 . $3 $(IMGR . $3 $: $) > $4 < $5 > $6
# Did any of the last three rules match? If so, call IspMailGate
R< $* @ $+ : ispmailgate > $* < $+ > $*
		$# ispmailgate $@ $2 $: $1 < @ $2 >

# Remove the preceding < user @ host >
R< $* @ $+ > $* < $+ > $*	$: $3 < $4 > $5
# Remove a .ISPMAILGATE, if present; call ruleset 3 for canonicalization
R$* < @ $+ .ISPMAILGATE. > $*	$: $>3 $1 @ $2
