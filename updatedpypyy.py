from cmath import log
import concurrent.futures
import logging.config
import subprocess
import sys
import os
import argparse
import zipfile
from processors import Util
from processors import TerraformProcessor
from processors import DeploymentDriver
import shutil
# import pandas
import yaml
from processors import TagProcessor


def exec_shell_command(cmd, logger):
    logger.info(os.getcwd())
    output = subprocess.Popen(cmd, shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    stdout, stderr = output.communicate()
    logger.info(stdout)
    rc = output.returncode
    logger.info("command return code is: {}".format(rc))
    return rc


def load_log_config():
    """
    Basic logger
    :return: Log object
    """
    root = logging.getLogger()
    root.addHandler(logging.StreamHandler(sys.stdout))
    root.setLevel(logging.INFO)
    return root

def setup_logger(app_name):
    logger = logging.getLogger(app_name)
    handler = logging.FileHandler(f"{app_name}_deployment.log")
    logger.addHandler(handler)
    logger.setLevel(logging.INFO)
    return logger



def update_provider(build_config_dl, local_bb_base, local_devops_base, vault_type):
    repo_name = build_config_dl.get("bb_repo_name")

    bb_local_directory = local_bb_base + "/{}".format(repo_name)
    if os.path.isdir(bb_local_directory):
        logging.info("{} exists..!".format(bb_local_directory))
        os.chdir(bb_local_directory)
        if (os.path.isfile(bb_local_directory + "/provider.tf") and vault_type == "new"):
            with open(bb_local_directory + "/provider.tf") as f:
                if '"gcp/' in f.read():
                    print("Found old format of provider.tf")

                    logging.info("New Provider Needed. Replace with Latest provider.tf")
                    shutil.copy2(local_devops_base + "/resources/ref_files/gcp/dpdf/dig/provider.tf", bb_local_directory + "/provider.tf")
                    logging.info("Replacement Complete")
            
        else:
            logging.info("No provider update is needed")

    else:
        logging.error("Local Bitbucket Directory missing {}".format(bb_local_directory))
        exit(-1)


def deploy_app(bb_repo_url, bb_branch_name, bb_repo_name, upgrade_param, dry_run, local_bb_base, local_devops_base, cloud_prov, platform_nm, core_noncore_param, env, account_nm, app_name, workspace_identifier, override_workspace_details, exec_code_base_type, build_config_dl, core_account_name):
    # Derive workspace name
                print("print deploy app details")
                print(app_name)
                print(account_nm)
                print(workspace_identifier)
                logger = setup_logger(app_name)

                # Check if deployment is core or non core; 
                # if core, using core grouping, deployment will run for all apps for the given common workspace identifier wherever matches 
                # if non-core, deployment will run on specific agent using the app noncore workspace identifier
                # Below information is used to create provider.tf in order to pickup correct workspace prefix, BU & TF Registry
                if (core_noncore_param == "core"):
                    yaml_BU_nm = yaml.full_load(open(local_devops_base + '/resources/ref_config/' + cloud_prov.lower() + '/' + platform_nm.lower() + '/' + core_noncore_param + '_workspace_mapping.yaml'))[env][account_nm.upper()]["account_info"]["BU"]
                    yaml_tf_registry = yaml.full_load(open(local_devops_base + '/resources/ref_config/' + cloud_prov.lower() + '/' + platform_nm.lower() + '/' + core_noncore_param + '_workspace_mapping.yaml'))[env][account_nm.upper()]["account_info"]["tf_registry"]
                    yaml_tf_token_registry = yaml.full_load(open(local_devops_base + '/resources/ref_config/' + cloud_prov.lower() + '/' + platform_nm.lower() + '/' + core_noncore_param + '_workspace_mapping.yaml'))[env][account_nm.upper()]["account_info"]["tf_token_registry"]
                    yaml_workspace_name = yaml.full_load(open(local_devops_base + '/resources/ref_config/' + cloud_prov.lower() + '/' + platform_nm.lower() + '/' + core_noncore_param + '_workspace_mapping.yaml'))[env][account_nm.upper()]["workspaces"][app_name.upper()][workspace_identifier.upper().strip()]["name"]
                    yaml_vault_type = yaml.full_load(open(local_devops_base + '/resources/ref_config/' + cloud_prov.lower() + '/' + platform_nm.lower() + '/' + core_noncore_param + '_workspace_mapping.yaml'))[env][account_nm.upper()]["workspaces"][app_name.upper()][workspace_identifier.upper().strip()]["vault_type"]
                else:
                    yaml_BU_nm = yaml.full_load(open(local_devops_base + '/resources/ref_config/' + cloud_prov.lower() + '/' + account_nm.lower() + '/' + core_noncore_param + '_workspace_mapping.yaml'))[env][account_nm.upper()]["account_info"]["BU"]
                    yaml_tf_registry = yaml.full_load(open(local_devops_base + '/resources/ref_config/' + cloud_prov.lower() + '/' + account_nm.lower() + '/' + core_noncore_param + '_workspace_mapping.yaml'))[env][account_nm.upper()]["account_info"]["tf_registry"]
                    yaml_tf_token_registry = yaml.full_load(open(local_devops_base + '/resources/ref_config/' + cloud_prov.lower() + '/' + account_nm.lower() + '/' + core_noncore_param + '_workspace_mapping.yaml'))[env][account_nm.upper()]["account_info"]["tf_token_registry"]
                    yaml_workspace_name = yaml.full_load(open(local_devops_base + '/resources/ref_config/' + cloud_prov.lower() + '/' + account_nm.lower() + '/' + core_noncore_param + '_workspace_mapping.yaml'))[env][account_nm.upper()]["workspaces"][app_name.upper()][workspace_identifier.upper().strip()]["name"]
                    yaml_vault_type = yaml.full_load(open(local_devops_base + '/resources/ref_config/' + cloud_prov.lower() + '/' + account_nm.lower() + '/' + core_noncore_param + '_workspace_mapping.yaml'))[env][account_nm.upper()]["workspaces"][app_name.upper()][workspace_identifier.upper().strip()]["vault_type"]
                
                # Extract tag information for the app
                yaml_data = yaml.full_load(open(local_devops_base + '/resources/env_yaml/' + cloud_prov.lower() + '/' + account_nm.lower() + '/' + app_name.lower() + '.yaml'))[env]

                logger.info(yaml_data)
                env_yaml_data = yaml_data['terraform']['tags']

                workspace_name = ""
                vault_type = ""

                if override_workspace_details != "":
                    workspace_name = override_workspace_details.split(",")[0]
                    vault_type = override_workspace_details.split(",")[1]
                else:
                    workspace_name = yaml_workspace_name
                    vault_type = yaml_vault_type

                workspace_prefix = yaml_workspace_name.split("-")[0]

                if exec_code_base_type == "BB":
                        build_config_dl["bb_repo_url"] = bb_repo_url
                        build_config_dl["base_branch"] = bb_branch_name
                        build_config_dl["bb_repo_name"] = bb_repo_name

                        # The below command will get repo name by reversing, parsing the bitbucket url
                        # example is: ssh://git@bitbucket.anthem.com:7999/digdpdfdl/dbg_kafka.git
                        logger.info("Repo url is {}".format(bb_repo_url))
                        # repo_name = bb_repo_url[::-1].split("/")[0][::-1].split(".")[0]

                        # build_config_dl["repo_name"] = bb_repo_name
                        logger.info("Repo name is {}".format(bb_repo_name))

                        # git clone pull in the bb url/branch
                        # local base location where repos are cloned/pulled is passed as local_bb_base
                        # update_provider(build_config_dl, local_bb_base, local_devops_base, vault_type)
                        TerraformProcessor.update_prefix(logging, workspace_prefix, build_config_dl, local_bb_base, local_devops_base, yaml_BU_nm, yaml_tf_registry, yaml_tf_token_registry)
                        


                # Prepare terraform commands
                terraform_init_command = TerraformProcessor.get_tf_init(env_yaml_data, workspace_name, upgrade_param)
                terraform_plan_command = TerraformProcessor.get_tf_plan(env_yaml_data, workspace_name)
                terraform_apply_command = TerraformProcessor.get_tf_apply(env_yaml_data, workspace_name)


                logger.info("TF init command is: \n {}".format(terraform_init_command))
                logger.info("TF plan command is: \n {}".format(terraform_plan_command))
                logger.info("TF apply command is: \n {}".format(terraform_apply_command))

                if (TagProcessor.create_auto_tfvars(env_yaml_data, cloud_prov, core_noncore_param, workspace_identifier, "default.auto.tfvars")):
                    logger.info("Successfully Created Tags auto tfvars file")
                else:
                    logger.error("Unable to create tag tfvar file")
                

                if (dry_run == "false"):
                    logger.info("dry run false; Starting Terraform execution")
                    TerraformProcessor.exec_terraform(logger, terraform_init_command, terraform_plan_command,
                                    terraform_apply_command)
                else:
                    logger.info("dry run true; Starting Terraform dry run")
                    TerraformProcessor.dry_run_terraform(logger, terraform_init_command, terraform_plan_command)
                    logger.info("********** Dry Run Successful ***********")

def main(env, app_name, bb_repo_url, bb_branch_name, bb_repo_name, local_tf_base, local_devops_base,local_bb_base, workspace_identifier, override_workspace_details, skip_deploy, terraform_deployment, exec_code_base_type, dry_run, cloud_prov, platform_nm, upgrade_param=""):
    logger = load_log_config()

    logger.info("Environment name is: {}".format(env))
    logger.info("Cloud provider name is: {}".format(cloud_prov))

    logger.info("Validating Workspace-Bitbucket mapping")
    if bb_repo_name.upper() not in workspace_identifier.upper():
        logger.error("********* Repo name not present in workspace identifier; Stopping deployment ********")
        exit(-1)
    elif 'SRGT' == workspace_identifier.upper().split('_')[-2] and app_name != workspace_identifier.upper().split('_')[-1] and bb_branch_name != 'develop':
        logger.error("********* Surrogate app_name is not matching or bb_branch is not master; Stopping deployment ********")
        exit(-1)        
    else:
        logger.info("Valid repo & workspace mapping. Continue with deployment.!")

    build_config_dl = {}

    # process arguments and prepare tags
    # py_rsc_directory = ""
    if cloud_prov == "aws":
        account_nm = workspace_identifier.split("_")[1]
        if(str(workspace_identifier).__contains__("_CORE_")):

            core_noncore_param = "core"

            yaml_core_group_list = yaml.full_load(open(local_devops_base + '/resources/ref_config/' + cloud_prov.lower() + '/' + platform_nm.lower() + '/' + 'core_grouping.yaml'))[env]["accounts"]
            for account in yaml_core_group_list: 
                yaml_core_account_app_list = yaml.full_load(open(local_devops_base + '/resources/ref_config/' + cloud_prov.lower() + '/' + platform_nm.lower() + '/' + 'core_app_mapping.yaml'))[account]

                # Overriding app_name as per the core app mapping instead of taking the one got in main
                #for app_name in yaml_core_account_app_list:
                #    deploy_app(logger, bb_repo_url, bb_branch_name, bb_repo_name, upgrade_param, dry_run, local_bb_base, local_devops_base, cloud_prov, platform_nm, core_noncore_param, env, account, app_name, workspace_identifier, override_workspace_details, exec_code_base_type, build_config_dl, core_account_name='AEDL' )
                with concurrent.futures.ProcessPoolExecutor() as executor:
                    executor.map(lambda app_name: deploy_app(bb_repo_url, bb_branch_name, bb_repo_name, upgrade_param, dry_run, local_bb_base, local_devops_base, cloud_prov, platform_nm, core_noncore_param, env, account, app_name, workspace_identifier, override_workspace_details, exec_code_base_type, build_config_dl, core_account_name='AEDL' )
, yaml_core_account_app_list)
                
        else:
            core_noncore_param = "noncore"
            
            deploy_app(bb_repo_url, bb_branch_name, bb_repo_name, upgrade_param, dry_run, local_bb_base, local_devops_base, cloud_prov, platform_nm, core_noncore_param, env, account_nm, app_name, workspace_identifier, override_workspace_details, exec_code_base_type, build_config_dl, core_account_name='' )

    else:
        logger.error("Invalid cloud provider")
        exit(-1)

    # # run terraform init
    # init_output = Util.exec_shell_command(tf_init_cmd)
    # stdout, stderr = init_output.communicate()
    # logger.info(stdout)
    # init_rc = init_output.returncode
    # logger.info("Terraform init return code is: {}".format(init_rc))
    # select workspace
    # run terraform apply


# Press the green button in the gutter to run the script.
if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Parse Terraform executor Args')
    parser.add_argument('--environment', metavar='<env name>', help='This is the ID number of the Resource', type=str,
                        default="dev")
    parser.add_argument('--team_app_name', metavar='<app team name>', help='app team name',
                        type=str,
                        default="")
    parser.add_argument('--bb_repo_url', metavar='<repository name>', help='repository name', type=str)
    parser.add_argument('--bb_branch_name', metavar='<bitbucket branch name>', help='bitbucket branch name', type=str)
    parser.add_argument('--bb_repo_name', metavar='<bitbucket branch name>', help='bitbucket branch name', type=str)
    parser.add_argument('--local_tf_base', metavar='<local terraform base>', help='local terraform base where TF repos are present', type=str,
                        default="./local_tf_base")
    parser.add_argument('--local_devops_base', metavar='<local devops base>', help='local devops base where CICD code exists', type=str,
                        default="./local_devops_base")
    parser.add_argument('--workspace_identifier', metavar='<workspace identifier>', help='workspace identifier to map to the right workspace', type=str,
                        default="AWS_AEDL_NCR_AEDL_DEFAULT_DEV_SLVR")
    parser.add_argument('--override_workspace_name', metavar='<local devops base>', help='override workspace instead of using workspace identifier mapping', type=str,
                        default="")
    parser.add_argument('--skip_deploy', metavar='<optional flag to skip deployment>', help='Deployment will be skipped if passed as Y; Default N',
                        type=str,
                        default="N")
    parser.add_argument('--terraform_deployment', metavar='<terraform deployment>', help='deployment involving terraform; Default Y; N means deploy using gcloud',
                        type=str,
                        default="Y")
    parser.add_argument('--exec_code_base_type', metavar='<Execution code base type>', help='Flag to decide where to pull the code from; artifactory/bucket or bitbucket directly; default is bitbucket',
                        type=str,
                        default="BB")
    parser.add_argument('--dry_run', metavar='<Flag to identify Dry run>', help='Flag to identify if execution is a dryrun; valid flags are true|false',
                        type=str,
                        default="false")
    parser.add_argument('--upgrade_tf', metavar='<upgrade terraform flag>', help='a flag passed to indicate if the TF state needs to be upgraded in the init command',
                        type=str,
                        default="false")
    parser.add_argument('--cloud_prov', metavar='<Cloud provider>', help='Cloud provider details; valid entries are aws|gcp',
                        type=str,
                        default="aws")
    parser.add_argument('--platform_nm', metavar='<Platform name>', help='Platform is where the deployments are going to happen; Valid values are DPDF|AEDL',
                        type=str,
                        default="aedl")
    args = parser.parse_args()

    local_bb_base = args.local_tf_base
    if (args.upgrade_tf == "true"):
        upgrade_param = "-upgrade"
    else:
        upgrade_param = ""

    # local_deploy_base = args.local_tf_base + "/deploy/"

    print(args)
    main(args.environment, args.team_app_name, args.bb_repo_url, args.bb_branch_name, args.bb_repo_name, args.local_tf_base, args.local_devops_base, local_bb_base, args.workspace_identifier, args.override_workspace_name, args.skip_deploy, args.terraform_deployment, args.exec_code_base_type, args.dry_run, args.cloud_prov, args.platform_nm, upgrade_param)
