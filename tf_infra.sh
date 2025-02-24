echo "Running Deployment script ..."
echo "Setting Variables."


print_usage()
{
    echo "usage: $0 -e | --environment <environment> -e 
                       | --team-app-name <team/app name> -t 
                       | --service-type <service type> -s 
                       | --artifact-name < artifact name> -a
                       | --artifact-path <artifact path>  -p
                       | --repo-url <repo URL> -u|
                       | --branch-name < bitbucket branch name> -b
                       | --repo-name < bitbucket branch name> -z
                       | --commit-id <commit id> -i
                       | --build-num <build number> -n
                       | --artf-credentials <artifactory credentials> -c
                       | --release <release> -r
                       | --local-tf-base <local-tf-base> -x
                       | --local-devops-base <local-devops-base> -y
                       | --workspace-identifier <workspace_identifier> -w
                       | --skip-deploy <flag to skip deployment> -d
                       | --upgrade-tf <flag to skip deployment> -d
                       | --cloud-prov <flag to skip deployment> -w
                       | --account_number <account number> -k
                       | --platform-nm <flag to skip deployment> -g"
}

# Transform long options to short ones

for arg in "$@"; do
  shift
  case "$arg" in
    "--environment")
    	set -- "$@" "-e" ;;
    "--account_number")
    	set -- "$@" "-k" ;;
    "--team-app-name")
    	set -- "$@" "-t" ;;
    "--service-type")
    	set -- "$@" "-s" ;;
    "--artifact-name")
    	set -- "$@" "-a" ;;
    "--artifact-path")
    	set -- "$@" "-p" ;;
    "--repo-url")
    	set -- "$@" "-u" ;;
    "--branch-name")
    	set -- "$@" "-b" ;;
    "--repo-name")
    	set -- "$@" "-z" ;;
    "--commit-id")
    	set -- "$@" "-i" ;;
    "--build-num")
    	set -- "$@" "-n" ;;
    "--artf-credentials")
    	set -- "$@" "-c" ;;
    "--skip-deploy")
    	set -- "$@" "-d" ;;
    "--release")
    	set -- "$@" "-r" ;;
    "--local-tf-base")
    	set -- "$@" "-x" ;;
    "--local-devops-base")
    	set -- "$@" "-y" ;;
    "--workspace-identifier")
    	set -- "$@" "-w" ;;
    "--upgrade-tf")
    	set -- "$@" "-g" ;;
    "--cloud-prov")
    	set -- "$@" "-f" ;;
    "--platform-nm")
    	set -- "$@" "-h" ;;
    "--"*)
    	echo "$0: illegal option -- ${arg:2}"
    	print_usage >&2; exit 2 ;;
    *)
    	set -- "$@" "$arg"
  esac
done

# Parse short options

OPTIND=1
while getopts ":e:t:s:a:p:u:b:z:i:n:c:d:r:x:y:w:g:f:h:k:" opt; do
  case ${opt} in
    e ) ENV=$(cut -d'-' -f1 <<< $OPTARG)
        echo "Environment = $ENV"
      ;;
    k ) ACCOUNT_NUMBER=$(cut -d'-' -f1 <<< $OPTARG)
        echo "ACCOUNT_NUMBER = $ACCOUNT_NUMBER"
      ;;
    t ) TEAM_APP_NAME=${OPTARG}
        echo "TEAM_APP_NAME = $TEAM_APP_NAME"
      ;;
    s ) SERVICE_TYPE=$OPTARG
        echo "SERVICE_TYPE = $SERVICE_TYPE"
      ;;
    a ) ARTIFACT_NAME=$OPTARG
        echo "Artifact Name = $ARTIFACT_NAME"
      ;;
    p ) ARTIFACT_PATH=$OPTARG
        echo "Artifact Path = $ARTIFACT_PATH"
      ;;
    u ) REPO_URL=$OPTARG
        echo "Bitbucket Repo URL = $REPO_URL"
      ;;
    b ) BRANCH_NAME=$OPTARG
        echo "Bitbucket Branch name = $BRANCH_NAME"
      ;;
    z ) REPO_NAME=$OPTARG
        echo "Bitbucket repo name = $REPO_NAME"
      ;;
    i ) COMMIT_ID=$OPTARG
        echo "Commit ID = $COMMIT_ID"
      ;;
    n ) BUILD_NUM=$OPTARG
        echo "Artifact Path = $BUILD_NUM"
      ;;
    c ) CREDS=$OPTARG
        echo "Credentials = $CREDS"
      ;;
    d ) SKIP_DEPLOY=$OPTARG
        echo "SKIP_DEPLOY = $SKIP_DEPLOY"
      ;;
    r ) RELEASE=$OPTARG
        echo "RELEASE = $RELEASE"
      ;;
    x ) TF_BASE=$OPTARG
        echo "TF_BASE = $TF_BASE"
      ;;
    y ) DEVOPS_BASE=$OPTARG
        echo "DEVOPS_BASE = $DEVOPS_BASE"
      ;;
    w ) WORKSPACE_IDENTIFIER=$OPTARG
        echo "WORKSPACE_IDENTIFIER = $WORKSPACE_IDENTIFIER"
      ;;
    g ) UPGRADE_TF=$OPTARG
        echo "UPGRADE_TF = $UPGRADE_TF"
      ;;
    f ) CLOUD_PROV=$OPTARG
        echo "CLOUD_PROV = $CLOUD_PROV"
      ;;
    h ) PLATFORM_NM=$OPTARG
        echo "PLATFORM_NM = $PLATFORM_NM"
      ;;
    ? ) print_usage >&2; exit 2 ;;
  esac
done
shift $((OPTIND - 1)) # Remove options from positional parameters

# Set Variables
DEVOPS_BASE=$HOME/$DEVOPS_BASE
EXECUTOR_DIR=$DEVOPS_BASE/eda_cicd_engine

# RELEASE_FILE_PATH=$EXECUTOR_DIR/resources/release_files

# Get code
TF_BASE=$HOME/local_tf_base
# ARTIFACT_DIR=$CODE_ROOT_DIR/$ENV/edl_aws_etl/$ARTIFACT_NAME
# echo "Working Directory = $WORK_DIR"

if [ -z $SKIP_DEPLOY ]; then
  SKIP_DEPLOY_ARG=""
elif [ $SKIP_DEPLOY = "Y" ]; then
  SKIP_DEPLOY_ARG=" --dry_run true"
else
  SKIP_DEPLOY_ARG=" --dry_run false"
fi
echo "SKIP DEPLOY FLAG IS : $SKIP_DEPLOY_ARG"

if [ -z $TEAM_APP_NAME ]; then
  TEAM_APP_NAME_ARG=""
else
  TEAM_APP_NAME_ARG=" --team_app_name ${TEAM_APP_NAME}"
  echo "TEAM_APP_NAME IS : $TEAM_APP_NAME"
fi

if [ -z $SERVICE_TYPE ]; then
  SERVICE_TYPE_ARG=""
else
  SERVICE_TYPE_ARG=" --service_type $SERVICE_TYPE"
  echo "SERVICE TYPE IS : $SERVICE_TYPE"
fi

if [ -z $UPGRADE_TF ]; then
  UPGRADE_TF_ARG=""
else
  UPGRADE_TF_ARG=" --upgrade_tf ${UPGRADE_TF}"
  echo "Upgrade TF param is : $UPGRADE_TF"
fi

if [ -z $CLOUD_PROV ]; then
  CLOUD_PROV_ARG=""
else
  CLOUD_PROV_ARG=" --cloud_prov ${CLOUD_PROV}"
  echo "Cloud provider TF param is : $CLOUD_PROV"
fi

if [ -z $PLATFORM_NM ]; then
  PLATFORM_NM_ARG=""
else
  PLATFORM_NM_ARG=" --platform_nm ${PLATFORM_NM}"
  echo "Platform name TF param is : $PLATFORM_NM"
fi
# rm -Rf $TF_BASE
# echo "Cleaned up working directory.!"

if [ ! -d $TF_BASE ]; then
  mkdir -p $TF_BASE
fi

cd $TF_BASE
if [ $? -eq 0 ]; then
  pwd=$(pwd)
  echo "Changed dir to $pwd"
else
  echo "unable to CD TO $TF_BASE"
  exit
fi


echo "Changed directory to $(pwd)"
echo "Listing contents from $TF_BASE"
echo `ls -ltr`

echo "start bb ssh"
eval $(ssh-agent -s)
ssh-add $HOME/.ssh/id_rsa
trap "kill $SSH_AGENT_PID" 0
echo "end bb ssh"

# Repo clone & pull
if [ ! -d $REPO_NAME ]; then
  # mkdir -p $WORK_DIR
  echo "Repo $REPO_NAME doesn't exist; need to clone"
  git clone $REPO_URL
  if [ $? == 0 ];then
    cd $REPO_NAME
    echo "Repo $REPO_NAME cloning successful; switched to new directory"
    git checkout $BRANCH_NAME
    git reset --hard
    git pull
    if [ $? -eq 0 ];then
      echo "Repo pull successful"
      echo "Pulled the latest code from $REPO_NAME $BRANCH_NAME"
    else
      echo "ERROR running git pull $REPO_NAME"
      echo "git pull failed; Exiting the script"
      exit
    fi
  else
    echo "Issue cloning  $REPO_URL"
    echo "Repo cloing failed; Exiting the script"
    exit
  fi
else
  echo "Repo $REPO_NAME already exists; need to pull"
  cd $REPO_NAME
  if [ $? -eq 0 ];then
    echo "changed directory to"
    pwd
    echo "Clean up and Pull latest files from git"
    # rm -rf *
    echo "Changed directory to $(pwd)"
    git checkout $BRANCH_NAME
    git reset --hard
    git pull origin $BRANCH_NAME
    if [ $? -eq 0 ];then
      echo "Repo pull successful"
      echo "Pulled the latest code from $REPO_NAME $BRANCH_NAME"
    else
      echo "ERROR running git pull $REPO_NAME"
      echo "git pull failed; Exiting the script"
      exit
    fi
  else
    echo "ERROR changing directory to $REPO_NAME"
    exit
  fi
fi

cd $HOME
if [ ! -d $DEVOPS_BASE ]; then
  mkdir -p $DEVOPS_BASE
fi

export CICD_REPO_NAME="eda_cicd_engine"
export CICD_REPO_URL="ssh://git@bitbucket.anthem.com:7999/aedldevops/eda_cicd_engine.git"

cd $DEVOPS_BASE
if [ $? -eq 0 ]; then
  pwd=$(pwd)
  echo "Changed dir to $pwd"
else
  echo "unable to CD TO $DEVOPS_BASE"
  exit
fi


# echo "Changed directory to $(pwd)"
echo `ls -ltr`
if [ ! -d $CICD_REPO_NAME ]; then
  # mkdir -p $WORK_DIR
  git clone $CICD_REPO_URL || (echo "Issue cloning  $CICD_REPO_URL"; exit -102)
  cd $CICD_REPO_NAME
  git checkout $BRANCH_NAME
  git reset --hard
  git pull || (echo "ERROR running git pull $CICD_REPO_NAME"; exit -102)
  echo "Repo Closing successful"
  # cd $CICD_REPO_NAME
else
  echo "Repo pull successful"
  cd $CICD_REPO_NAME || (echo "ERROR changing directory to $REPO_NAME"; exit -102)
  echo "Changed directory to $(pwd)"
  git checkout $BRANCH_NAME
  git reset --hard
  git pull || (echo "ERROR running git pull $CICD_REPO_NAME"; exit -102)
  echo "Pulled the latest code from $CICD_REPO_NAME $BRANCH_NAME"
fi

echo "python3 main.py --team_app_name $TEAM_APP_NAME --environment $ENV --local_tf_base $TF_BASE --local_devops_base $EXECUTOR_DIR --workspace_identifier $WORKSPACE_IDENTIFIER --bb_repo_url $REPO_URL --bb_branch_name $BRANCH_NAME --account_name $ACCOUNT_NAME --bb_repo_name $REPO_NAME$SKIP_DEPLOY_ARG$UPGRADE_TF_ARG$CLOUD_PROV_ARG$PLATFORM_NM_ARG"

python3 main.py --team_app_name $TEAM_APP_NAME --environment $ENV --account_name $ACCOUNT_NAME --local_tf_base $TF_BASE --local_devops_base $EXECUTOR_DIR --workspace_identifier $WORKSPACE_IDENTIFIER --bb_repo_url $REPO_URL --bb_branch_name $BRANCH_NAME --bb_repo_name $REPO_NAME$SKIP_DEPLOY_ARG$UPGRADE_TF_ARG$CLOUD_PROV_ARG$PLATFORM_NM_ARG
if [ $? -eq 0 ]; then
  echo "*********** Executed deployment successfully ***********"
else
  echo "*********** Executed deployment Failed ***********"
  # remove_working_directory
  exit -201
fi
