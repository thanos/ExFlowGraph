defmodule ExFlowGraph.Examples.WorkflowExamples do
  @moduledoc """
  Example workflows demonstrating ExFlow usage patterns.

  These examples show how to create various types of workflows using ExFlow.
  Use these as templates for your own workflows.
  """

  @doc """
  Creates a simple sequential workflow.

  ## Example

      iex> workflow = WorkflowExamples.simple_sequential()
      iex> ExFlow.save(workflow, "simple-sequential")
      :ok

  """
  def simple_sequential do
    ExFlow.new()
    |> ExFlow.add_node!("start", :trigger,
      x: 0,
      y: 200,
      label: "Start",
      description: "Workflow entry point"
    )
    |> ExFlow.add_node!("step1", :task,
      x: 200,
      y: 200,
      label: "Step 1",
      description: "First processing step"
    )
    |> ExFlow.add_node!("step2", :task,
      x: 400,
      y: 200,
      label: "Step 2",
      description: "Second processing step"
    )
    |> ExFlow.add_node!("step3", :task,
      x: 600,
      y: 200,
      label: "Step 3",
      description: "Final processing step"
    )
    |> ExFlow.add_node!("end", :output,
      x: 800,
      y: 200,
      label: "Complete",
      description: "Workflow completion"
    )
    |> ExFlow.add_edge!("e1", "start", "step1")
    |> ExFlow.add_edge!("e2", "step1", "step2")
    |> ExFlow.add_edge!("e3", "step2", "step3")
    |> ExFlow.add_edge!("e4", "step3", "end")
  end

  @doc """
  Creates a conditional branching workflow.

  Demonstrates decision nodes with multiple output paths.
  """
  def conditional_branching do
    ExFlow.new()
    |> ExFlow.add_node!("start", :trigger,
      x: 0,
      y: 200,
      label: "Start"
    )
    |> ExFlow.add_node!("validate", :task,
      x: 200,
      y: 200,
      label: "Validate Input",
      validations: ["required_fields", "data_types"]
    )
    |> ExFlow.add_node!("decision", :decision,
      x: 400,
      y: 200,
      label: "Is Valid?",
      condition: "validation_result == :ok"
    )
    |> ExFlow.add_node!("process", :task,
      x: 600,
      y: 100,
      label: "Process Data",
      description: "Process valid data"
    )
    |> ExFlow.add_node!("error-handler", :task,
      x: 600,
      y: 300,
      label: "Handle Error",
      description: "Handle validation errors"
    )
    |> ExFlow.add_node!("success", :output,
      x: 800,
      y: 100,
      label: "Success"
    )
    |> ExFlow.add_node!("failure", :output,
      x: 800,
      y: 300,
      label: "Failure"
    )
    |> ExFlow.add_edge!("e1", "start", "validate")
    |> ExFlow.add_edge!("e2", "validate", "decision")
    |> ExFlow.add_edge!("e3", "decision", "process",
      source_handle: "yes",
      label: "Valid"
    )
    |> ExFlow.add_edge!("e4", "decision", "error-handler",
      source_handle: "no",
      label: "Invalid"
    )
    |> ExFlow.add_edge!("e5", "process", "success")
    |> ExFlow.add_edge!("e6", "error-handler", "failure")
  end

  @doc """
  Creates a parallel processing workflow.

  Demonstrates splitting work across multiple parallel tasks.
  """
  def parallel_processing do
    ExFlow.new()
    |> ExFlow.add_node!("start", :trigger,
      x: 0,
      y: 300,
      label: "Start"
    )
    |> ExFlow.add_node!("split", :task,
      x: 200,
      y: 300,
      label: "Split Work",
      description: "Divide work into chunks"
    )
    |> ExFlow.add_node!("worker1", :task,
      x: 400,
      y: 100,
      label: "Worker 1",
      worker_id: 1
    )
    |> ExFlow.add_node!("worker2", :task,
      x: 400,
      y: 200,
      label: "Worker 2",
      worker_id: 2
    )
    |> ExFlow.add_node!("worker3", :task,
      x: 400,
      y: 300,
      label: "Worker 3",
      worker_id: 3
    )
    |> ExFlow.add_node!("worker4", :task,
      x: 400,
      y: 400,
      label: "Worker 4",
      worker_id: 4
    )
    |> ExFlow.add_node!("merge", :task,
      x: 600,
      y: 300,
      label: "Merge Results",
      description: "Combine worker results"
    )
    |> ExFlow.add_node!("end", :output,
      x: 800,
      y: 300,
      label: "Complete"
    )
    |> ExFlow.add_edge!("e1", "start", "split")
    |> ExFlow.add_edge!("e2", "split", "worker1", source_handle: "out-1")
    |> ExFlow.add_edge!("e3", "split", "worker2", source_handle: "out-2")
    |> ExFlow.add_edge!("e4", "split", "worker3", source_handle: "out-3")
    |> ExFlow.add_edge!("e5", "split", "worker4", source_handle: "out-4")
    |> ExFlow.add_edge!("e6", "worker1", "merge", target_handle: "in-1")
    |> ExFlow.add_edge!("e7", "worker2", "merge", target_handle: "in-2")
    |> ExFlow.add_edge!("e8", "worker3", "merge", target_handle: "in-3")
    |> ExFlow.add_edge!("e9", "worker4", "merge", target_handle: "in-4")
    |> ExFlow.add_edge!("e10", "merge", "end")
  end

  @doc """
  Creates an ETL (Extract, Transform, Load) pipeline.

  Demonstrates a data processing workflow.
  """
  def etl_pipeline do
    ExFlow.new()
    |> ExFlow.add_node!("source", :input,
      x: 0,
      y: 0,
      label: "Data Source",
      source_type: "database",
      connection: "postgres://localhost/mydb"
    )
    |> ExFlow.add_node!("extract", :task,
      x: 200,
      y: 0,
      label: "Extract",
      query: "SELECT * FROM users",
      batch_size: 1000
    )
    |> ExFlow.add_node!("clean", :task,
      x: 400,
      y: 0,
      label: "Clean Data",
      operations: ["remove_nulls", "trim_strings", "normalize_emails"]
    )
    |> ExFlow.add_node!("transform", :task,
      x: 600,
      y: 0,
      label: "Transform",
      transformations: ["add_timestamps", "hash_passwords", "format_phone"]
    )
    |> ExFlow.add_node!("validate", :decision,
      x: 800,
      y: 0,
      label: "Validate",
      schema: "user_schema_v2"
    )
    |> ExFlow.add_node!("load", :task,
      x: 1000,
      y: 0,
      label: "Load",
      target: "data_warehouse",
      table: "users_cleaned"
    )
    |> ExFlow.add_node!("error-log", :task,
      x: 1000,
      y: 100,
      label: "Log Errors",
      destination: "error_log_table"
    )
    |> ExFlow.add_node!("complete", :output,
      x: 1200,
      y: 0,
      label: "Complete"
    )
    |> ExFlow.add_edge!("e1", "source", "extract")
    |> ExFlow.add_edge!("e2", "extract", "clean")
    |> ExFlow.add_edge!("e3", "clean", "transform")
    |> ExFlow.add_edge!("e4", "transform", "validate")
    |> ExFlow.add_edge!("e5", "validate", "load", source_handle: "valid")
    |> ExFlow.add_edge!("e6", "validate", "error-log", source_handle: "invalid")
    |> ExFlow.add_edge!("e7", "load", "complete")
    |> ExFlow.add_edge!("e8", "error-log", "complete")
  end

  @doc """
  Creates an AI agent workflow.

  Demonstrates an autonomous agent with planning and execution.
  """
  def ai_agent_workflow do
    ExFlow.new()
    |> ExFlow.add_node!("input", :input,
      x: 0,
      y: 300,
      label: "User Input",
      input_type: "text"
    )
    |> ExFlow.add_node!("understand", :agent,
      x: 200,
      y: 300,
      label: "Understand Intent",
      model: "gpt-4",
      temperature: 0.7,
      max_tokens: 500
    )
    |> ExFlow.add_node!("plan", :agent,
      x: 400,
      y: 300,
      label: "Create Plan",
      model: "gpt-4",
      system_prompt: "You are a planning agent"
    )
    |> ExFlow.add_node!("execute", :task,
      x: 600,
      y: 300,
      label: "Execute Plan",
      max_retries: 3
    )
    |> ExFlow.add_node!("verify", :decision,
      x: 800,
      y: 300,
      label: "Verify Results",
      criteria: ["completeness", "correctness"]
    )
    |> ExFlow.add_node!("respond", :output,
      x: 1000,
      y: 300,
      label: "Respond to User"
    )
    |> ExFlow.add_node!("retry", :task,
      x: 600,
      y: 400,
      label: "Retry with Feedback",
      max_attempts: 3
    )
    |> ExFlow.add_edge!("e1", "input", "understand")
    |> ExFlow.add_edge!("e2", "understand", "plan")
    |> ExFlow.add_edge!("e3", "plan", "execute")
    |> ExFlow.add_edge!("e4", "execute", "verify")
    |> ExFlow.add_edge!("e5", "verify", "respond", source_handle: "success")
    |> ExFlow.add_edge!("e6", "verify", "retry", source_handle: "failure")
    |> ExFlow.add_edge!("e7", "retry", "execute")
  end

  @doc """
  Creates an order processing workflow.

  Demonstrates a real-world e-commerce workflow.
  """
  def order_processing do
    ExFlow.new()
    |> ExFlow.add_node!("receive", :trigger,
      x: 0,
      y: 300,
      label: "Receive Order",
      webhook: "/api/orders"
    )
    |> ExFlow.add_node!("validate", :task,
      x: 200,
      y: 300,
      label: "Validate Order",
      checks: ["items_available", "payment_valid", "address_valid"]
    )
    |> ExFlow.add_node!("check-inventory", :task,
      x: 400,
      y: 300,
      label: "Check Inventory",
      reserve_items: true
    )
    |> ExFlow.add_node!("process-payment", :task,
      x: 600,
      y: 300,
      label: "Process Payment",
      provider: "stripe"
    )
    |> ExFlow.add_node!("payment-check", :decision,
      x: 800,
      y: 300,
      label: "Payment Success?"
    )
    |> ExFlow.add_node!("fulfill", :task,
      x: 1000,
      y: 200,
      label: "Fulfill Order",
      warehouse: "main"
    )
    |> ExFlow.add_node!("ship", :task,
      x: 1200,
      y: 200,
      label: "Ship Order",
      carrier: "fedex"
    )
    |> ExFlow.add_node!("notify-success", :output,
      x: 1400,
      y: 200,
      label: "Send Confirmation",
      template: "order_confirmation"
    )
    |> ExFlow.add_node!("refund", :task,
      x: 1000,
      y: 400,
      label: "Process Refund"
    )
    |> ExFlow.add_node!("notify-failure", :output,
      x: 1400,
      y: 400,
      label: "Send Failure Notice",
      template: "order_failed"
    )
    |> ExFlow.add_edge!("e1", "receive", "validate")
    |> ExFlow.add_edge!("e2", "validate", "check-inventory")
    |> ExFlow.add_edge!("e3", "check-inventory", "process-payment")
    |> ExFlow.add_edge!("e4", "process-payment", "payment-check")
    |> ExFlow.add_edge!("e5", "payment-check", "fulfill", source_handle: "success")
    |> ExFlow.add_edge!("e6", "payment-check", "refund", source_handle: "failure")
    |> ExFlow.add_edge!("e7", "fulfill", "ship")
    |> ExFlow.add_edge!("e8", "ship", "notify-success")
    |> ExFlow.add_edge!("e9", "refund", "notify-failure")
  end

  @doc """
  Saves all example workflows to storage.

  ## Example

      WorkflowExamples.save_all_examples()

  """
  def save_all_examples do
    examples = [
      {"simple-sequential", simple_sequential()},
      {"conditional-branching", conditional_branching()},
      {"parallel-processing", parallel_processing()},
      {"etl-pipeline", etl_pipeline()},
      {"ai-agent-workflow", ai_agent_workflow()},
      {"order-processing", order_processing()}
    ]

    Enum.each(examples, fn {name, workflow} ->
      case ExFlow.save(workflow, name) do
        :ok -> IO.puts("✓ Saved: #{name}")
        {:error, reason} -> IO.puts("✗ Failed to save #{name}: #{inspect(reason)}")
      end
    end)

    IO.puts("\nSaved #{length(examples)} example workflows")
  end

  @doc """
  Lists all example workflows.
  """
  def list_examples do
    [
      "simple-sequential",
      "conditional-branching",
      "parallel-processing",
      "etl-pipeline",
      "ai-agent-workflow",
      "order-processing"
    ]
  end

  @doc """
  Loads an example workflow by name.

  ## Example

      {:ok, workflow} = WorkflowExamples.load_example("simple-sequential")

  """
  def load_example(name) when name in [
        "simple-sequential",
        "conditional-branching",
        "parallel-processing",
        "etl-pipeline",
        "ai-agent-workflow",
        "order-processing"
      ] do
    ExFlow.load(name)
  end

  def load_example(_name) do
    {:error, :invalid_example_name}
  end
end
