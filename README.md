badr-data-platform/
├── infra/                # Infrastructure as Code (Terraform or CloudFormation)
│   ├── main.tf           # Defines S3 buckets, IAM roles, Glue jobs
│   └── variables.tf
├── src/                  # The actual logic
│   ├── producer/         # Runs on EC2
│   │   ├── producer.py
│   │   └── requirements.txt
│   ├── glue/             # Runs in AWS Glue (Spark)
│   │   ├── jobs/
│   │   │   ├── silver_layer.py
│   │   │   └── gold_layer.py
│   │   └── schemas/       # JSON schema definitions for validation
├── scripts/              # Automation scripts
│   ├── deploy_glue.sh    # Syncs local python files to S3 scripts folder
│   └── setup_ec2.sh      # Bootstraps the EC2 instance (installs python, cron)
├── README.md
└── .gitignore