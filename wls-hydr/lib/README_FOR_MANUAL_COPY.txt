############################
INSTRUCTIONS FOR MANUAL COPY
############################
OHS:
####
      - Copy the content of the folder OHS_PRODUCTS of the OHS node 1 to 
            <stage>/webtier/ohs_products_home/ohs_products_home1 folder.
      ---
      TIP: For example, if your OHS_PRODUCTS folder is /u02/oracle/products and it 
              contains the folders "ohs12214","jdk","oraInventory", copy these 
            folders directly under <stage>/webtier/ohs_products_home/ohs_products_home1. 
            The same approach applies for the rest of the copies.
      ---
      - Copy the content of the folder OHS_PRODUCTS of the OHS node 2 to 
            <stage>/webtier/ohs_products_home/ohs_products_home2 folder.
      - If there are more OHS nodes, you don't need to copy more OHS_PRODUCTS folders. 
            The tool uses only 2 copies of the OHS products home to provide redundancy and minimize storage size.
      - Copy the content of the folder OHS_PRIVATE_CONFIG_DIR of the OHS node 1 
            to <stage>/webtier/ohs_private_config/ohsnode1_private_configfolder.
      - Copy the content of the folder OHS_PRIVATE_CONFIG_DIR of the OHS node 2 
            to <stage>/webtier/ohs_private_config/ohsnode2_private_config folder.
      - If there are more OHS nodes, copy the content of the folder OHS_PRIVATE_CONFIG_DIR 
            of the OHS node N to <stage>/webtier/ohs_private_config/ohsnodeN_private_config folder.
      - If the JDK is NOT located under the OHS products folder (OHS_PRODUCTS), copy the content of the folder 
            OHS_JDK_DIR to <stage>/webtier/ohs_jdk_dir.

WLS:
####
      - Copy the content of the folder WLS_PRODUCTS of the WLS node 1 to 
            <stage>/midtier/wls_products_home/wls_products_home1 folder.
      ---
      TIP: For example, if your WLS_PRODUCTS folder is /u01/oracle/products and it 
              contains the folders "fmw","jdk","oraInventory", copy these folders 
            directly under <stage>/midtier/wls_products_home/wls_products_home1. 
            The same approach applies for the rest of the copies.
      ---
      - Copy the content of the folder WLS_PRODUCTS of the WLS node 2 to 
            <stage>/midtier/wls_products_home/wls_products_home2 folder.
      - If there are more WLS nodes, you don't need to copy more WLS_PRODUCTS folders. 
            The tool uses only 2 copies of the WLS products home to provide redundancy and minimize storage size.
      - Copy the content of the folder WLS_PRIVATE_CONFIG_DIR of the WLS node 1 
            to <stage>/midtier/wls_private_config/wlsnode1_private_config folder.
      - Copy the content of the folder WLS_PRIVATE_CONFIG_DIR of the WLS node 2 
            to <stage>/midtier/wls_private_config/wlsnode2_private_config folder.
      - If there are more WLS nodes, copy the content of the folder WLS_PRIVATE_CONFIG_DIR 
            of the WLS node N to <stage>/midtier/wls_private_config/wlsnodeN_private_config folder.
      - If you are using a shared config dir, copy the content of the folder 
            WLS_SHARED_CONFIG_DIR that you want to replicate (e.g. domains, applications, deployment plans, keystores) 
            to <stage>/midtier/wls_shared_config folder.
      - Copy the tnsnames.ora file of your primary WebLogic domain in the 
            bastion's <stage>/midtier/var folder.
      - If the JDK is NOT located under the WLS products folder (WLS_PRODUCTS), copy the content of the folder 
            WLS_JDK_DIR  to <stage>/midtier/wls_jdk_dir.