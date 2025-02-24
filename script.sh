echo ${bamboo.planRepository.name}
export HOME=/home/bmboagt
export TERRAFORM_HOME="$HOME/tools"
export PATH=$JAVA_HOME/bin:$PATH:$TERRAFORM_HOME
export PATH=$PATH:$HOME/tools
# export $PATH
export DEPLOY_REPO="edl_deploy"
export DEPLOY_REPO_PATH="$HOME/$DEPLOY_REPO"
export DEPLOY_REPO_URL="ssh://git@bitbucket.anthem.com:7999/aedldevops/edl_deploy.git"
export DEPLOY_BRANCH_NAME="${bamboo.planRepository.branchName}"
# git archive --format tar --remote=ssh://git@bitbucket.anthem.com:7999/digdpdfdo/dbg_deploy.git HEAD:scripts tf_infra.sh | tar xv
cd $HOME

if [ ! -d $DEPLOY_REPO_PATH ]; then
  # mkdir -p $WORK_DIR
  echo "Repo $DEPLOY_REPO doesn't exist; need to clone"
  git clone $DEPLOY_REPO_URL
  if [ $? == 0 ];then
    cd $DEPLOY_REPO_PATH
    echo "Repo $DEPLOY_REPO cloning successful; switched to new directory"
    git checkout $DEPLOY_BRANCH_NAME
    git reset --hard
    git pull
    if [ $? -eq 0 ];then
      echo "Repo pull successful"
      echo "Pulled the latest code from $DEPLOY_REPO $DEPLOY_BRANCH_NAME"
    else
      echo "ERROR running git pull $DEPLOY_REPO"
      echo "git pull failed; Exiting the script"
      exit
    fi
  else
    echo "Issue cloning  $DEPLOY_REPO_URL"
    echo "Repo cloing failed; Exiting the script"
    exit
  fi
else
  echo "Repo $DEPLOY_REPO already exists; need to pull"
  cd $DEPLOY_REPO_PATH
  if [ $? -eq 0 ];then
    echo "changed directory to"
    pwd
    echo "Clean up and Pull latest files from git"
    # rm -rf *
    echo "Changed directory to $(pwd)"
    git checkout $DEPLOY_BRANCH_NAME
    git reset --hard
    git pull origin $DEPLOY_BRANCH_NAME
    if [ $? -eq 0 ];then
      echo "Repo pull successful"
      echo "Pulled the latest code from $DEPLOY_REPO $DEPLOY_BRANCH_NAME"
    else
      echo "ERROR running git pull $DEPLOY_REPO"
      echo "git pull failed; Exiting the script"
      exit
    fi
  else
    echo "ERROR changing directory to $DEPLOY_REPO"
    exit
  fi
fi

repo_name=`echo ${bamboo.planRepository.repositoryUrl} | rev | cut -d. -f2 | cut -d/ -f1 | rev`
echo $repo_name
ls
echo "bash tf_infra.sh --environment ${bamboo.deploy.environment} --workspace-identifier ${bamboo.workspaceIdentifier} --team-app-name ${bamboo.teamAppName} --service-type S3 --repo-url ${bamboo.planRepository.repositoryUrl} --branch-name ${bamboo.planRepository.branchName} --repo-name ${repo_name} --commit-id ${bamboo.planRepository.revision} --build-num ${bamboo.buildNumber} --skip-deploy ${bamboo.SKIP_DEPLOY} --release ${bamboo.deploy.release} --local-devops-base local_devops_base --local-tf-base local_tf_base"
bash tf_infra.sh --environment ${bamboo.deploy.environment} --workspace-identifier ${bamboo.workspaceIdentifier} --team-app-name ${bamboo.teamAppName} --service-type S3 --repo-url ${bamboo.planRepository.repositoryUrl} --branch-name ${bamboo.planRepository.branchName} --repo-name ${repo_name} --commit-id ${bamboo.planRepository.revision} --build-num ${bamboo.buildNumber} --release ${bamboo.deploy.release} --local-devops-base local_devops_base --local-tf-base local_tf_base --skip-deploy ${bamboo.SKIP_DEPLOY}