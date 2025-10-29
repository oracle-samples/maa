connect('<OIG_WLS_ADMIN_USER>','<OIG_WLS_PWD>','<OIG_T3>://<OIG_ADMIN_HOST>:<OIG_ADMIN_PORT>')
grantAppRole(appStripe="soa-infra",  appRoleName="SOAAdmin",principalClass="weblogic.security.principal.WLSGroupImpl", principalName="<LDAP_WLSADMIN_GRP>")
grantAppRole(appStripe="wsm-pm",  appRoleName="policy.Updater",principalClass="weblogic.security.principal.WLSGroupImpl", principalName="<LDAP_WLSADMIN_GRP>")
exit()
