resource "aws_glue_workflow" "medallion_pipeline" {
  name = "badr-medallion-main-workflow"
}

resource "aws_glue_trigger" "start_trigger" {
  name          = "trigger-start-pipeline"
  type          = "SCHEDULED"
  schedule      = "cron(0 * * * ? *)" # Runs every hour
  workflow_name = aws_glue_workflow.medallion_pipeline.name

  actions {
    job_name = aws_glue_job.silver_layer.name
  }
}

# silver job -> silver crawler
resource "aws_glue_trigger" "silver_to_crawler" {
  name          = "trigger-silver-success-to-crawler"
  type          = "CONDITIONAL"
  workflow_name = aws_glue_workflow.medallion_pipeline.name
  enabled       = true

  predicate {
    conditions {
      job_name = aws_glue_job.silver_layer.name
      state    = "SUCCEEDED"
    }
  }

  actions {
    crawler_name = aws_glue_crawler.silver_crawler.name
  }
}

# silver crawler -> gold job
resource "aws_glue_trigger" "crawler_to_gold" {
  name          = "trigger-crawler-success-to-gold"
  type          = "CONDITIONAL"
  workflow_name = aws_glue_workflow.medallion_pipeline.name

  predicate {
    conditions {
      crawler_name = aws_glue_crawler.silver_crawler.name
      crawl_state  = "SUCCEEDED"
    }
  }

  actions {
    job_name = aws_glue_job.gold_layer.name
  }
}

# gold job -> gold crawler
resource "aws_glue_trigger" "gold_to_crawler" {
  name          = "trigger-gold-success-to-crawler"
  type          = "CONDITIONAL"
  workflow_name = aws_glue_workflow.medallion_pipeline.name

  predicate {
    conditions {
      job_name = aws_glue_job.gold_layer.name
      state    = "SUCCEEDED"
    }
  }

  actions {
    crawler_name = aws_glue_crawler.gold_crawler.name
  }
}