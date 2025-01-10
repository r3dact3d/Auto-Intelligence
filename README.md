# Open WebUI with Ollama on AWS EC2 via Terraform

## Terraform Infrastructure

### Summary

This project leverages Terraform to provision infrastructure and integrates GitHub Actions for streamlined automation. Key features include:

- A publicly accessible EC2 instance running on AWS.
- AWS infrastructure and instance configuration automated with Terraform.
- GitHub Actions workflows for:
  - Automatically creating a Terraform plan on a pull request.
  - Applying infrastructure changes upon pull request merge.

> **Note:** Familiarize yourself with all resources in the `terraform` directory, particularly `main.tf`.

---

### Architecture Diagram

   > **Note:**  
   > - The ec2 details are out of date, see `terraform` code in `main.tf`.  
---

### Implementation

#### Procedure

1. **Gather Requirements**
   - Clone the GitHub repository.

2. **Configure Repository Secrets**  
   Add the following secrets in the GitHub repository settings:  

   - `AWS_ACCESS_KEY`  
   - `AWS_SECRET_ACCESS_KEY`  
   > **Note:**
   > - Below 2 secrets are only needed for rhel servers that need to be registered
   - `ORG_ID` (Profile in [cloud.redhat.com](https://cloud.redhat.com))  
   - `ACTIVATION_KEY` (Created in **Inventory > System Configuration > Activation Keys** [console.redhat.com](https://console.redhat.com/insights/connector/activation-keys#SIDs=&tags=))  


 
  ![Actions Secrets](images/github_secrets.png)  


1. **Validate Terraform Manifests**  
   Review and update files in the `terraform` directory as necessary:  
   - `main.tf`  
   - `output.tf`  
   - `user_data.txt`  

   > **Note:**  
   - Ensure your SSH public key is added to `user_data.txt`.  *This is the public key from your laptop or bastion server so you can ssh in for maintenance and run installer.*
   - Create an S3 bucket referenced in the backend configuration of `main.tf` (e.g., `tfstate-bucket-auto-intelligence`).  *If you use a different name look and update the code.*
   - Review `remote-exec` custom code for specifics to configure ec2 instance in `main.tf`.


#### Pull Request Validation

4. **Automated Validation with GitHub Actions**  
   GitHub Actions will validate pull requests with the following Terraform steps before allowing a merge:  
   - `terraform fmt`  
   - `terraform init`  
   - `terraform validate`  
   - `terraform plan`  

   > **Note:**  
   - DO NOT MERGE until you are happy with the terraform plan if you update anything in `terraform` directory the GitHub Actions Workflow will kick off.
---

### Post-Infrastructure: Installing Ollama and Open WebUI

5. **Review Terraform Outputs**  
   After the GitHub Actions workflow completes, retrieve instance details from the output.  
   - Use the public IP to SSH into the instance (`ec2-user`).

   Validate:  
   - Expected results from `user_data.txt`.  
   - Expected results from the provisioner in `main.tf`.  
  
   ![Terraform Output](images/tf_output.png)

6. **Install **  

   From the machine with the corresponding SSH keys that were added to the `user_data.txt` :  

   ```bash
   ssh ec2-user@<public IP>
   ```

   To install Open WebUI docker container that is bundled with Ollama
   ```bash
   docker run -d -p 3000:8080 --gpus=all -v ollama:/root/.ollama -v open-webui:/app/backend/data --name open-webui --restart always ghcr.io/open-webui/open-webui:ollama
   ```

   At this point, we should be able to access the Open WebUI through our browser at *https://public IP/:3000* so we can login first as Admin and do initial config.

   > To get a model into Ollama I also had to execute the below commands.

   ```bash
   docker exec -it open-webui /bin/bash
   ```
   Once, I'm at the docker prompt, I can pull the model I want.
   ```bash
   ollama pull llama2
   ```

   Now, I can go back to my Open WebUI chat window and see the model available.

   > However, looks like I could have done that through Open WebUI if I had followed this document > https://docs.openwebui.com/getting-started/quick-start/starting-with-ollama 



