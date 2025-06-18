# Sunrise Base Project

This is a starter project for the **Sunrise** open-source low-code platform. It provides:

* A backend written in Golang
* Infrastructure provisioning using Terraform on Google Cloud Platform (GCP)
* A GitHub Actions pipeline for CI/CD via Workload Identity Federation (WIF)
* A basic Flutter frontend app
* A Cloud SQL MySQL database (managed)
* Deployment to Cloud Run (serverless)

---

## 📁 Project Structure

```
sunrise/
├── backend/                  # Golang HTTP server (Hello, World!)
├── env/                      # Sample environment configuration
├── flutter_app/              # Basic Flutter app (Hello, World!)
├── terraform/                # Terraform for GCP provisioning
└── .github/workflows/        # GitHub Actions CI/CD pipeline
```

---

## ⚙️ Prerequisites

Before you begin, make sure you have the following tools installed and configured on your local machine:

* **bash** (or another Unix-compatible shell)
* **Go** (version 1.24 or later)
  Install from [https://go.dev/dl/](https://go.dev/dl/) and verify with `go version`
* **gcloud CLI** (Google Cloud SDK)
  Install from [https://cloud.google.com/sdk/docs/install](https://cloud.google.com/sdk/docs/install) and authenticate with `gcloud auth login`
* **Terraform** (version 1.12 or later recommended)
  Install from [https://developer.hashicorp.com/terraform/downloads](https://developer.hashicorp.com/terraform/downloads) and verify with `terraform version`
* **Git** (for source control and pushing code)
  Install from [https://git-scm.com/downloads](https://git-scm.com/downloads) and verify with `git --version`
* **(Optional) Flutter** (for running the frontend app, optional at initial backend deployment)
  Install from [https://docs.flutter.dev/get-started/install](https://docs.flutter.dev/get-started/install) and verify with `flutter --version`
* **(Optional) Firebase CLI**
  Install from [https://firebase.google.com/docs/cli#install_the_firebase_cli](https://firebase.google.com/docs/cli#install_the_firebase_cli) and login to the CLI `firebase login`
* **(Optional) Activate flutterfire CLI globally** (for initiating Firebase configuration in Flutter project)
  Run this command `dart pub global activate flutterfire_cli`. This will install the CLI and make it available as a global tool.
* **(Optional) Docker** (for building container images locally)
  Install from [https://docs.docker.com/get-docker/](https://docs.docker.com/get-docker/) and verify with `docker version`

Make sure these are all installed and working before proceeding with the setup steps.

---

## ✅ Setup Instructions

### 1. Clone the Repository

```bash
git clone https://github.com/lslaine/Sunrise.git
cd Sunrise
```

---

### 2. Configure Terraform & GCP

#### 2.1 Create a GCP Project (if you haven’t already)

* Go to [https://console.cloud.google.com/](https://console.cloud.google.com/)
* Create a new project
* Enable these APIs:

  * Cloud Run Admin API (`run.googleapis.com`)
  * Cloud SQL Admin API (`sqladmin.googleapis.com`)
  * Artifact Registry API (`artifactregistry.googleapis.com`)
  * IAM Credentials API  (`iamcredentials.googleapis.com`)
  * Identity and Access Management (IAM) API (`iam.googleapis.com`)

#### 2.2 Provision GCP Infra with Terraform

Terraform will:

* Create a Workload Identity Pool and GitHub Provider
* Create a GCP Service Account with required roles:

  * Cloud Run Admin
  * Cloud SQL Admin
  * Service Account Token Creator
  * Artifact Registry Writer
* Bind GitHub repo identity to impersonate the service account
* Use Google Cloud Storage (GCS) to securely store Terraform state

To set up:

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars:
# project_id        = "your-gcp-project-id"          # Your GCP project ID
# project_number    = "123456789012"                 # Your GCP project number (find in GCP Console)
# project_name      = "your-project-name"            # Your desired project name in the same format xxx-xxx
# github_repository = "your-org/your-repo"           # GitHub repo in owner/repo format
# region            = "europe-west4"                 # Your preferred GCP region
```
⚠️ Make sure to provide correct values, especially `project_number` and `github_repository`, as they are used for IAM bindings.

---

#### 🔧 Running Terraform Manually (First Time Setup)

For the first run, GitHub Actions cannot authenticate yet — because Terraform hasn’t created the service account and identity provider. So you **must run Terraform manually** once:

##### ✅ 1. Authenticate to GCP

```bash
gcloud auth login
gcloud config set project your-gcp-project-id
```

##### ✅ 2. Export Sensitive Variables

Terraform needs `db_password` at runtime:

```bash
export TF_VAR_db_password="your-db-password"
```

##### ✅ 3. Initialize and Apply Terraform

Run: 

```bash
cd terraform
terraform init -backend=false
terraform apply     # Or use: terraform apply -auto-approve
```

> **Note:**
> On the very first run, Terraform may fail to create the Cloud Run service because the container image is not yet pushed to Google Container Registry. This error is expected and can be safely ignored at this stage.
> Once you push the image via your GitHub Actions workflow, subsequent Terraform runs will succeed.

After successful apply (or partial success):

* Note the generated **Workload Identity Provider** path and **Service Account email**
* Add them to your GitHub repository secrets (mentioned in Step 3)

##### ✅ 4. Re-enable the GCS Backend

After the infrastructure is successfully provisioned (even partially), switch to using the remote backend.

If not already set correctly, update the bucket name in backend.tf to match the GCS bucket created during provisioning by replacing `<your-project-id>`:

```hcl
terraform {
  backend "gcs" {
    bucket = "<your-project-id>-terraform-state"
    prefix = "terraform/state"
  }
}
```

Then **re-initialize Terraform to use the remote backend**:

```bash
terraform init -reconfigure
```

By default, Terraform will prompt you:

"Do you want to copy the existing state to the new backend?"

⚠️ Make sure to answer **`yes`** so it uploads the local state (terraform.tfstate) to the GCS bucket.

---

### 3. GitHub Actions: Configure OIDC + Secrets

#### 3.1 Add GitHub Repository Secrets

Go to your GitHub repo:

**Settings → Secrets and Variables → Actions → New Repository Secret**

Add the following:

| Secret Name                      | Description                                                                                                                                    |
| -------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------- |
| `GCP_PROJECT_ID`                 | Your Google Cloud project ID                                                                                                                   |
| `GCP_PROJECT_NAME`               | Your desired project name MUST BE SAME as project_name set in `terraform.tfvars`                                                               |
| `GCP_SERVICE_ACCOUNT`            | The full email of the service account created by Terraform                                                                                     |
| `GCP_WORKLOAD_IDENTITY_PROVIDER` | Full Workload Identity Provider path (e.g., `projects/123456789/locations/global/workloadIdentityPools/github-pool/providers/github-provider`) |
| `DB_PASSWORD`                    | Password for the MySQL database (used during provisioning and deploy)                                                                          |

> ⚠️ You do **not** need to store any service account key JSON — authentication is handled securely via WIF and OIDC tokens from GitHub Actions.

---

### 4. Deploy via GitHub Actions

**Before pushing**, you **MUST initialize your Go module locally** if you haven’t done so yet:

```bash
cd backend
go mod init github.com/yourusername/project-name-backend  # Replace with your module path
go mod tidy                                               # Optional but recommended to download dependencies
cd ..
```

#### ⚠️ Deployment temporarily disabled by default

> **Note:** The GitHub Actions workflow for deployment (`.github/workflows/deploy.yml`) includes a safeguard to prevent accidental deployment during initial setup.
> It contains this condition to skip execution:

```yaml
if: false
```

> This allows you to safely push code without triggering unintended infrastructure changes.

#### ✅ How to enable deployment

* Once you have completed manual Terraform setup and verified everything works, you can enable GitHub Actions deployment by **removing or updating** the `if: false` line in `.github/workflows/deploy.yml`:

```yaml
# Change from:
if: false

# To:
# (either remove the line entirely or set proper condition if needed)
if: true
```

Then push your changes to GitHub `main` branch:

```bash
git add .
git commit -m "Initial deploy to Cloud Run"
git push origin main
```

This triggers GitHub Actions, which:

* Authenticates to GCP via WIF (OIDC)
* Builds and pushes Docker image to Artifact Registry
* Provisions Cloud SQL instance and users
* Deploys the backend to Cloud Run
* Injects secrets via environment variables

---

### 5. Get Backend URL

After deployment, check in **Google Cloud Console → Cloud Run → Your service → URL**

> ⚠️ **Note:** The backend is private by default (not publicly accessible). Only authenticated requests will succeed.

---

### 6. (Optional) Connect Flutter Frontend to Backend + Firebase Authentication

To enable secure access to your private Cloud Run backend, we integrate Firebase Authentication into the Flutter app and send authenticated requests using Firebase ID tokens.

---

#### 🔐 Enable Firebase Authentication Manually

##### ✅ How to Manually Enable Firebase in the Console

1. **Go to the Firebase Console**
   👉 [https://console.firebase.google.com/](https://console.firebase.google.com/)

2. **Click "Add project"** (or select your existing GCP project)

3. **Click "Add Firebase to your Google Cloud project"**  
   > Use the **same GCP project** you used in your `terraform.tfvars`.

4. **Click "Continue"** and follow the setup prompts  
   > Confirm billing and API access when asked

5. **Enable Firebase Authentication**

   * In the Firebase Console navigate to **Build → Authentication**
   * Click **"Get Started"**
   * Under **Sign-in method**, enable **Google**
   * Click **Save**

---

#### 🧰 Configure `flutterfire` CLI

If you haven’t yet, install the FlutterFire CLI:

```bash
dart pub global activate flutterfire_cli
```

Then log in to Firebase:

```bash
firebase login
```

Now configure your Flutter app to use Firebase:

```bash
cd flutter_app
flutterfire configure
```

Follow the prompts:

* Select your Firebase project
* Choose your platform(s) — **android**, **ios**, **web** etc.
* Provide your app ID (e.g., `com.example.app`)

> This generates `lib/firebase_options.dart` and sets up the native platform configs.

---

#### 🔧 Update Your Flutter Code

In your `lib/main.dart`:

* Uncomment the `import 'firebase_options.dart';` & `
* Update the Firebase initialization:

```dart
await Firebase.initializeApp(
  options: DefaultFirebaseOptions.currentPlatform,
);
```

* Replace this constant with your deployed Cloud Run URL:

```dart
static const String backendUrl = '<CLOUD_RUN_URL>';
```

---

#### 🚀 Run the App

```bash
cd flutter_app
flutter pub get
flutter run
```

Make sure:

✅ You’ve replaced `<CLOUD_RUN_URL>` with your deployed Cloud Run endpoint
✅ You’re signed in with a Google account that Firebase recognizes
✅ Firebase project has Authentication → Google Sign-In enabled

---

## 🧪 Test the Deployment

This Cloud Run backend is **secured using Firebase Authentication** — all main routes require a valid Firebase ID token in the `Authorization` header.

### 🔓 Public Health Check

You can test whether the service is deployed correctly by accessing the public `/test` path in (<your-cloud-run-url>/test) browser or as below:

```bash
CLOUD_RUN_URL="<your-cloud-run-url>"

curl "$CLOUD_RUN_URL/test"
````

Expected output:

```
OK TEST
```

This endpoint does **not** require authentication and can be used for basic connectivity checks.

---