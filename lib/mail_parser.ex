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
  Similar to extract_attachments/1 but writes the attachments to the dest_dir.

  It returns filenames of the extracted attachments having the prefix prepended to them.

  ### Example

      iex> MailParser.extract_attachments_to_disk(raw_message, "dir_1", "account-")
      {:ok, ["account-example.pdf"}

  """
  @spec extract_attachments_to_disk(String.t(), String.t(), String.t()) :: {:ok, [Attachment.t()]} | :error
  def extract_attachments_to_disk(_raw_message, _dest_dir, _prefix), do: :erlang.nif_error(:nif_not_loaded)
end
