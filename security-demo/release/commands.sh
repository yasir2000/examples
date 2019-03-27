#!/bin/bash 

#Generically using . to source env config , should be present in the same path as the script
. ./edge.env

show_all_entries()
{
  return=$($SPIRE_PATH/spire-server entry show 2>&1)
  err=$?
  if [ $? -eq 0 ]; then
     echo "listing all entries registered with spire server."
     echo "$return"
  else
     echo "failed with error : $return "
  fi
  exit $err
}


validate_app_name()
{
   if [ -z $1 ]; then
      echo "invalid app name : $1"
      exit 1
   fi
}

validate_app_selector()
{
   if [ -z $1 ]; then
      echo "invalid app name : $1"
      exit 1
   fi
}

create_upstream_workload()
{

# TBD : automate selection of spire server 
# TBD : automate selection of parentid
# TBD : add validation 

  return=$($SPIRE_PATH/spire-server entry create -parentID spiffe://example.org/upstream-cloud-node -spiffeID spiffe://example.org/upstream-app-$1 -selector $2 2>&1)
  err=$?
  if [ $? -eq 0 ]; then
     echo "created upstream cloud upstream app entry upstream-app-$1."
     echo "returned token = $return"
  else
     echo "failed with error : $return "
  fi
  exit $err 
}

start_cloud_hub()
{
# TBD : Due to dependency of ghostunnel on keystore , on the initial run , start-spiffe-helper.sh should be run manually after creating cloud-node.
#       spiffe-helper requires initial certificates to be downloaded to start ghostunnel with keystore .

#     if [ -e $SPIRE_PATH/certs/svid.pem ]; then
     if [ -e $SPIRE_PATH/certs/svid.pem ]; then
       cd $SPIRE_PATH/app-binaries/
       pwd=`pwd`
       echo "changed directory to $pwd"
       nohup ./cloud-app 2>&1 1> $SPIRE_PATH/log/cloudhub.log &
       cd $SPIRE_PATH/
       pwd=`pwd`
       echo "changed directory to $pwd"
       nohup bash -x $SPIRE_PATH/start-spiffe-helper.sh
# Ignore nohup errors 
     else 
       echo "Kill and run spiffe helper manually using command - $SPIRE_PATH/start-spiffe-helper.sh"
       echo "Or rerun this command"
       bash -x $SPIRE_PATH/start-spiffe-helper.sh 
     fi
     exit 0
}

# TBD : create upstream cloud node with name as parameter
create_cloud_node()
{
  token=$($SPIRE_PATH/spire-server token generate -spiffeID spiffe://example.org/upstream-cloud-node 2>&1)
  if [ $? -eq 0 ]; then 
     echo "created upstream cloud node entry upstream-cloud-node."
     echo "returned token = $token"

#TBD : check error handling if there is missing second parameter
     token=$(echo $token | awk '{print $2}')
	 
#TBD : error handling for nohup commands 
     nohup $SPIRE_PATH/spire-agent run -joinToken $token -logFile $SPIRE_PATH/log/upstream-agent.log &
     if [ $? -eq 0 ]; then
       echo "started upstream agent in upstream-cloud-node."
       echo "returned token = $return"
     else
       echo "failed with error : $return "
     fi 
  else 
     echo "failed with error : $token " 
     err=$?
  fi
  exit $err
}

start_identity_server()
{
#TBD : error handling for nohup commands
     nohup $SPIRE_PATH/spire-server run -logFile $SPIRE_PATH/log/spire-server.log &
     if [ $? -eq 0 ]; then
       echo "started upstream server in upstream-cloud-node."
       echo "returned token = $return"
     else
       echo "failed with error : $return "
     fi
     exit 0
}

#################### edge functions ###############
# TBD : create upstream cloud node with name as parameter
create_edgeapp_node()
{
  token=$($SPIRE_PATH/spire-server token generate -spiffeID spiffe://example.org/downstream-edge-node 2>&1)
  if [ $? -eq 0 ]; then 
     echo "created downstream cloud node entry downstream-edge-node."
     echo "returned token = $token"

#TBD : check error handling if there is missing second parameter
     token=$(echo $token | awk '{print $2}')
	 
#TBD : error handling for nohup commands 
     nohup $SPIRE_PATH/spire-agent run -config $SPIRE_PATH/app-agent-conf/agent/agent.conf -joinToken $token -logFile $SPIRE_PATH/log/downstream-edgeapp-agent.log &
     if [ $? -eq 0 ]; then
       echo "started downstream agent in downstream-edge-node."
       echo "returned token = $return"
     else
       echo "failed with error : $return "
     fi 

  else 
     echo "failed with error : $token " 
     err=$?
  fi
  exit $err
}

# TBD : create upstream cloud node with name as parameter
create_edge_node()
{
  local token
#  token=$($SPIRE_PATH/spire-server token generate -config $SPIRE_PATH/edge-package/conf/server/server.conf -spiffeID spiffe://example.org/upstream-edge-node 2>&1)
# TBD : get server config path, upstream vm ip and port , ssh username and password from config files and source the config, presently hardcoding to finish off the working 
#       PoC .
  token=$(sshpass -p $CLOUD_VM_PASS ssh $CLOUD_VM_USER@$CLOUD_VM_IP $SPIRE_PATH/spire-server token generate -spiffeID spiffe://example.org/upstream-edge-node 3>&1)
  err=$?
  if [ $? -eq 0 ]; then 
     echo "created upstream edge node entry upstream-edge-node."
     echo "returned token = $token"

#TBD : check error handling if there is missing second parameter
     token=$(echo $token | awk '{print $2}')
	 
#TBD : error handling for nohup commands 
     nohup $SPIRE_PATH/spire-agent run -joinToken $token -logFile $SPIRE_PATH/log/edge-agent.log &
     if [ $? -eq 0 ]; then
       echo "started upstream agent in upstream-edge-node."
       echo "returned token = $return"
     else
       echo "failed with error : $return "
     fi 
  else 
     echo "failed with error : $token " 
  fi
  exit $err
}

create_edge_control_app()
{

# TBD : automate selection of spire server 
# TBD : automate selection of parentid
# TBD : add validation 

#  return=$($SPIRE_PATH/spire-server entry create -parentID spiffe://example.org/upstream-edge-node -spiffeID spiffe://example.org/downstream-app-$1 -selector $2 2>&1)
  local return
  return=$(sshpass -p $CLOUD_VM_PASS ssh $CLOUD_VM_USER@$CLOUD_VM_IP $SPIRE_PATH/spire-server entry create -parentID spiffe://example.org/upstream-edge-node -spiffeID spiffe://example.org/upstream-edgeapp-$1 -selector $2 -downstream true 2>&1)
  if [ $? -eq 0 ]; then
     echo "created downstream edge app entry upstream-edgeapp-$1."
     echo "returned token = $return"
  else
     echo "failed with error : $return "
  fi

}

create_user_app()
{

# TBD : automate selection of spire server 
# TBD : automate selection of parentid
# TBD : add validation 

  return=$($SPIRE_PATH/spire-server entry create -config $SPIRE_PATH/edge-package/conf/server/server.conf -parentID spiffe://example.org/downstream-edge-node -spiffeID spiffe://example.org/downstream-app-$1 -selector $2 2>&1)
  err=$?
  if [ $? -eq 0 ]; then
     echo "created downstream edge app entry downstream-app-$2."
     echo "returned token = $return"
  else
     echo "failed with error : $return "
  fi
  exit $err
}

start_edge_hub()
{
# TBD : Due to dependency of ghostunnel on keystore , on the initial run , start-spiffe-helper.sh should be run manually after creating cloud-node.
#       spiffe-helper requires initial certificates to be downloaded to start ghostunnel with keystore .

     if [ -e $SPIRE_PATH/certs/svid.pem ]; then
       cd $SPIRE_PATH/app-binaries/ 
       pwd=`pwd`
       echo "changed to directory $pwd"
       nohup sudo ./edge_core 2>&1 1>$SPIRE_PATH/log/edge-core.log & 
       cd $SPIRE_PATH/
       pwd=`pwd`
       echo "changed to directory $pwd"
       nohup bash -x $SPIRE_PATH/start-spiffe-helper.sh 
# Ignore nohup errors 
     else 
       echo "Kill and run spiffe helper manually using command - $SPIRE_PATH/start-spiffe-helper.sh"
       echo "Or rerun this command"
       bash -x $SPIRE_PATH/start-spiffe-helper.sh 
     fi
     exit 0
}

start_edge_identity_server()
{
#TBD : error handling for nohup commands
     nohup $SPIRE_PATH/spire-server run  -logFile $SPIRE_PATH/log/spire-server.log &
     if [ $? -eq 0 ]; then
       echo "started edge identity server in edge node."
       echo "$return"
     else
       echo "failed with error : $return"
     fi
     exit 0
}

create_user_agent()
{
  token=$($SPIRE_PATH/spire-server token generate -spiffeID spiffe://example.org/downstream-edge-node 2>&1)
# TBD : get server config path, upstream vm ip and port , ssh username and password from config files and source the config, presently hardcoding to finish off the working 
#       PoC .
  err=$?
  if [ $? -eq 0 ]; then 
     echo "created downstream edge node entry downstream-edge-node."
     echo "returned token = $token"

#TBD : check error handling if there is missing second parameter
     token=$(echo $token | awk '{print $2}')
	 
#TBD : error handling for nohup commands 
     nohup $SPIRE_PATH/spire-agent run -joinToken $token -logFile $SPIRE_PATH/log/edge-agent.log &
     if [ $? -eq 0 ]; then
       echo "started upstream agent in upstream-cloud-node."
       echo "returned token = $return"
     else
       echo "failed with error : $return "
     fi 
  else 
     echo "failed with error : $token " 
  fi
  exit $err
}

create_edge_app()
{

# TBD : automate selection of spire server 
# TBD : automate selection of parentid
# TBD : add validation 

  return=$($SPIRE_PATH/spire-server entry create -parentID spiffe://example.org/downstream-edge-node -spiffeID spiffe://example.org/downstream-app-$1 -selector $2 2>&1)
  err=$?
  if [ $? -eq 0 ]; then
     echo "created downstream edge app entry downstream-app-$1."
     echo "returned token = $return"
  else
     echo "failed with error : $return "
  fi
  exit $err
}

start_edge_event_bus()
{
     if [ -e $SPIRE_PATH/event-bus/certs/svid.pem ]; then
       echo "started event bus helper ghostunnel"
       cd $SPIRE_PATH/event-bus/
       nohup bash -x .//start-spiffe-helper.sh
       cd $SPIRE_PATH/
# Ignore nohup errors 
     else
       echo "Kill and run spiffe helper manually using command - $SPIRE_PATH/event-bus/start-spiffe-helper.sh \n"
       echo "Or rerun this command"
       cd $SPIRE_PATH/event-bus/
       bash -x $SPIRE_PATH/event-bus/start-spiffe-helper.sh
       cd $SPIRE_PATH/
     fi
     exit 0
}

start_edge_app()
{
     if [ -e $SPIRE_PATH/user-app/certs/svid.pem ]; then
       cd $SPIRE_PATH/user-app/
       nohup bash -x ./start-spiffe-helper.sh
       cd $SPIRE_PATH/
       echo "Run the user application to use ip and port configured as per $SPIRE_PATH/user-app/user-app-helper.conf"
# Ignore nohup errors 
     else
       echo "Kill and run spiffe helper manually using command - $SPIRE_PATH/user-app/start-spiffe-helper.sh"
       echo "Or rerun this command"
       cd $SPIRE_PATH/user-app/
       bash -x $SPIRE_PATH/user-app/start-spiffe-helper.sh
       cd $SPIRE_PATH/
     fi
     exit 0
}

echo $1 option selected 
echo $2 parameters selected

case $1 in 
  "start-cloud-hub")
        start_cloud_hub
        ;;
  "start-cloud-server")
        start_identity_server
        ;;
  "cloud-node") 
        create_cloud_node
        ;;
  "cloud-app")
        validate_app_name $2
        validate_app_selector $3
        create_upstream_workload $2 $3
        ;;
  "edge-control-app")
        validate_app_name $2
        validate_app_selector $3
#        validate_user_server_ip $4
        create_edge_control_app $2 $3 $4
        ;;
  "edge-app")
        validate_app_name $2
        validate_app_selector $3
#        validate_user_server_ip $4
        create_edge_app $2 $3 $4
        ;;
  "start-edge-hub")
        start_edge_hub
        ;;
  "show-entry")
        show_all_entries
        ;;
  "edge-node")
        create_edge_node
        ;;
  "edge-app-node")
        create_edgeapp_node
        ;;
  "start-edge-server")
        start_edge_identity_server
        ;;
  "start-edge-event-bus")
        start_edge_event_bus
        ;;
  "start-edge-app")
        start_edge_app
	;;
  "help")
        help_instructions
        ;;
  *) 
        echo "invalid option"
	exit 1
	;;
esac

help_instructions()
{
  echo " Valid options :"
  echo " \tstart-cloud-server - start identity server (spire server)"
  echo " \tcloud-node   - creates cloud upstream node"
  echo " \tcloud-app    - creates entry for cloud app with identity server (usage - cloud-app <appname> <selector> e.g: cloud-app cloud-hub unix:uid:1000)"
  echo " \tstart-cloud-hub - starts cloud hub "
  echo " \tstart-edge-server  - starts identity server (spire server) at edge node"
  echo " \tedge-node    - creates edge node to connect attested by upstream identity server"
  echo " \tedge-app     - creates entry for edge_core application with edge identity server "
  echo " \tstart-edge-hub - starts edge hub"
  echo " \tstart-edge-event-bus - starts helper and tunnel to connect to edge control components"
  echo " \tstart-edge-app - starts user application"
  echo " \thelp         - shows this menu"

  echo " \tshow-entry   - displays all entries registered with identity server"
}

