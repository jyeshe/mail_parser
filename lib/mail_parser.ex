defmodule MailParser do
  @moduledoc """
  NIF binding of mail_parser using Rustler which parses a string containing a RFC5322 raw message.
  """

  mix_config = Mix.Project.config()
  version = mix_config[:version]
  github_url = mix_config[:package][:links]["GitHub"]

  use RustlerPrecompiled,
    otp_app: :mail_parser,
    crate: :mail_parser_nif,
    mode: if(Mix.env() in [:prod, :bench], do: :release, else: :debug),
    base_url: "#{github_url}/releases/download/v#{version}",
    force_build: System.get_env("FORCE_BUILD") in ["1", "true"],
    version: version

  alias __MODULE__.Attachment

  @doc """
  Extracts attachments from an email.

  A best-effort is made to parse the message and if no headers are found `:error` is returned.

  ### Example

      iex> MailParser.extract_nested_attachments(raw_message)
      {:ok, [%MailParser.Attachment{
        name: "example.pdf",
        content_type: "application/pdf",
        content_bytes: "..."}]}

  """
  @spec extract_nested_attachments(String.t()) :: {:ok, [Attachment.t()]} | :error
  def extract_nested_attachments(_raw_message), do: :erlang.nif_error(:nif_not_loaded)

  @doc """
  Similar to extract_attachments/1 but writes the attachments to an optional directory.

  It returns filenames of the extracted attachments having an optional prefix prepended to them to avoid conflicts.

  ## Options

  * `:directory` - Directory to save attachments to. Defaults to current directory (".")
  * `:prefix` - Prefix to prepend to filenames. Defaults to empty string ("")
  * `:mime_types` - List of MIME types to filter attachments. Only attachments
    matching at least one of these types will be saved. If not specified or empty,
    all attachments are saved.

  ### Examples

      # Save all attachments to current directory with no prefix
      iex> raw_message = "Date: Mon, 17 Feb 2026 10:00:00 +0000\\nFrom: test@example.com\\n\\nTest email"
      iex> MailParser.extract_attachments_to_disk(raw_message, [])
      {:ok, []}

      # Save to specific directory with prefix (example with attachments)
      # MailParser.extract_attachments_to_disk(email_with_attachments, directory: "dir_1", prefix: "account-")
      # {:ok, ["account-example.pdf", "account-image.jpg"]}

      # Filter by MIME types (example with attachments)
      # MailParser.extract_attachments_to_disk(email_with_attachments,
      #   directory: "dir_1",
      #   prefix: "account-",
      #   mime_types: ["application/pdf", "image/jpeg"])
      # {:ok, ["account-example.pdf"]}

  """
  @spec extract_attachments_to_disk(String.t(), keyword()) :: {:ok, [String.t()]} | :error
  def extract_attachments_to_disk(_raw_message, _opts \\ []), do: :erlang.nif_error(:nif_not_loaded)
end
