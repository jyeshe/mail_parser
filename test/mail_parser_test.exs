defmodule MailParserTest do
  use ExUnit.Case, async: false

  doctest MailParser, except: [
    extract_nested_attachments: 1
  ]

  describe "extract_nested_attachments/1" do
    test "extracts attachments from raw message" do
      raw_message = File.read!("test/fixtures/example.txt")

      assert {:ok,
              [
                %MailParser.Attachment{
                  name: "Best 340 Klöckner FL-Stahl.pdf",
                  content_type: "application/pdf",
                  content_bytes: pdf_content_bytes
                },
                %MailParser.Attachment{
                  name: "smime.p7s",
                  content_type: "application/x-pkcs7-signature",
                  content_bytes: "redacted"
                }
              ]} = MailParser.extract_nested_attachments(raw_message)

      assert pdf_content_bytes == File.read!("test/fixtures/sample.pdf")
    end

    test "returns error if parsing fails" do
      assert :error = MailParser.extract_nested_attachments("")
    end
  end

  describe "extract_attachments_to_disk/2" do
    @temp_dir "/tmp/mailparser/test"
    @filenames ["test_document.pdf", "test_image.jpg"]

    setup do
      File.mkdir_p!(@temp_dir)
      on_exit(fn ->
        File.rm_rf!(@temp_dir)
        Enum.each(@filenames, &File.rm/1)
      end)
    end

    test "extracts no attachments from email without attachments" do
      raw_message = File.read!("test/fixtures/email_without_attachment.txt")

      assert {:ok, []} = MailParser.extract_attachments_to_disk(raw_message, directory: @temp_dir)
    end

    test "extracts attachments from email with attachments" do
      raw_message = File.read!("test/fixtures/email_with_attachment.txt")

      assert {:ok, @filenames} = MailParser.extract_attachments_to_disk(raw_message, directory: @temp_dir)

      # Verify files were created
      assert File.exists?(Path.join(@temp_dir, "test_document.pdf"))
      assert File.exists?(Path.join(@temp_dir, "test_image.jpg"))
    end

    test "adds prefix to filenames" do
      raw_message = File.read!("test/fixtures/email_with_attachment.txt")

      assert {:ok, filenames} = MailParser.extract_attachments_to_disk(raw_message,
        directory: @temp_dir,
        prefix: "email-123-"
      )

      assert "email-123-test_document.pdf" in filenames
      assert "email-123-test_image.jpg" in filenames

      # Verify files were created with prefix
      assert File.exists?(Path.join(@temp_dir, "email-123-test_document.pdf"))
      assert File.exists?(Path.join(@temp_dir, "email-123-test_image.jpg"))
    end

    test "filters attachments by MIME type" do
      raw_message = File.read!("test/fixtures/email_with_attachment.txt")

      # Only extract PDF files
      assert {:ok, filenames} = MailParser.extract_attachments_to_disk(raw_message,
        directory: @temp_dir,
        mime_types: ["application/pdf"]
      )

      assert length(filenames) == 1
      assert "test_document.pdf" in filenames
      refute "test_image.jpg" in filenames

      # Verify only PDF was created
      assert File.exists?(Path.join(@temp_dir, "test_document.pdf"))
      refute File.exists?(Path.join(@temp_dir, "test_image.jpg"))
    end

    test "filters attachments by multiple MIME types" do
      raw_message = File.read!("test/fixtures/email_with_attachment.txt")

      # Extract both PDF and JPEG files
      assert {:ok, filenames} = MailParser.extract_attachments_to_disk(raw_message,
        directory: @temp_dir,
        mime_types: ["application/pdf", "image/jpeg"]
      )

      assert ["test_document.pdf", "test_image.jpg"] = filenames

    end

    test "returns empty list when no attachments match MIME type filter" do
      raw_message = File.read!("test/fixtures/email_with_attachment.txt")

      # Filter for a MIME type that doesn't exist in the email
      assert {:ok, []} = MailParser.extract_attachments_to_disk(raw_message,
        directory: @temp_dir,
        mime_types: ["text/plain"]
      )

      # Verify no files were created
      assert Enum.empty?(File.ls!(@temp_dir))
    end

    test "uses current directory as default when no directory specified" do
      raw_message = File.read!("test/fixtures/email_with_attachment.txt")

      # Should work without specifying directory (defaults to ".")
      assert {:ok, ["test_document.pdf", "test_image.jpg"]} = MailParser.extract_attachments_to_disk(raw_message)
      assert File.exists?("test_document.pdf")
      assert File.exists?("test_image.jpg")
    end

    test "combines all options: directory, prefix, and mime_types" do
      raw_message = File.read!("test/fixtures/email_with_attachment.txt")

      assert {:ok, filenames} = MailParser.extract_attachments_to_disk(raw_message,
        directory: @temp_dir,
        prefix: "filtered-",
        mime_types: ["image/jpeg"]
      )

      assert length(filenames) == 1
      assert "filtered-test_image.jpg" in filenames

      # Verify only the filtered file with prefix was created
      assert File.exists?(Path.join(@temp_dir, "filtered-test_image.jpg"))
      refute File.exists?(Path.join(@temp_dir, "filtered-test_document.pdf"))
    end

    test "returns error for invalid email" do
      # The parser might still extract "attachments" from malformed emails, so let's use completely invalid input
      assert :error = MailParser.extract_attachments_to_disk("", directory: @temp_dir)
    end
  end
end
