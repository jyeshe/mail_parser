use mail_parser::{Message, MessagePart, MimeHeaders};
use rustler::{Atom, Binary, Env, Error, NifResult, NifStruct, OwnedBinary, Term};
use rustler::{Decoder, Encoder};
use std::fs;
use std::path::Path;

mod atoms {
    rustler::atoms! {
        ok,
        mime_types,
        directory,
        prefix
    }
}

#[derive(Clone, Debug, NifStruct)]
#[module = "MailParser.Attachment"]
struct Attachment {
    name: String,
    content_type: Option<String>,
    content_bytes: ContentBytes,
}

impl From<&MessagePart<'_>> for Attachment {
    fn from(part: &MessagePart) -> Self {
        let name = part.attachment_name().unwrap_or("untitled").to_string();
        let content_bytes = ContentBytes::new(part.contents());

        let content_type = part.content_type().map(|content_type| {
            let roottype = content_type.ctype();

            match content_type.subtype() {
                Some(subtype) => format!("{roottype}/{subtype}"),
                None => roottype.to_string(),
            }
        });

        Attachment {
            name,
            content_bytes,
            content_type,
        }
    }
}

#[derive(Clone, Debug)]
struct ContentBytes(Vec<u8>);

impl ContentBytes {
    fn new(content_bytes: &[u8]) -> Self {
        ContentBytes(content_bytes.to_vec())
    }
}

impl Encoder for ContentBytes {
    fn encode<'a>(&self, env: Env<'a>) -> Term<'a> {
        let mut owned_binary = OwnedBinary::new(self.0.len()).expect("allocation failed");
        owned_binary.as_mut_slice().copy_from_slice(&self.0);
        Binary::from_owned(owned_binary, env).encode(env)
    }
}
impl Decoder<'_> for ContentBytes {
    fn decode(term: Term) -> NifResult<ContentBytes> {
        Ok(Self(term.to_binary().to_vec()))
    }
}

fn get_attachments(message: &Message) -> Vec<Attachment> {
    message
        .attachments()
        .flat_map(|attachment| match attachment.message() {
            Some(nested_message) => get_attachments(nested_message),
            None => Vec::from([attachment.into()]),
        })
        .collect()
}

fn get_mime_types_from_opts(opts: &[(Atom, Term)]) -> NifResult<Vec<String>> {
    for (atom, term) in opts.iter() {
        if *atom == atoms::mime_types() {
            return term.decode::<Vec<String>>();
        }
    }
    Ok(Vec::new())
}

fn get_directory_from_opts(opts: &[(Atom, Term)]) -> NifResult<String> {
    for (atom, term) in opts.iter() {
        if *atom == atoms::directory() {
            return term.decode::<String>();
        }
    }
    Ok(".".to_string()) // Default to current directory
}

fn get_prefix_from_opts(opts: &[(Atom, Term)]) -> NifResult<String> {
    for (atom, term) in opts.iter() {
        if *atom == atoms::prefix() {
            return term.decode::<String>();
        }
    }
    Ok("".to_string()) // Default to empty prefix
}

fn filter_by_mime_type(attachments: &Vec<Attachment>, mime_types: &[String]) -> Vec<Attachment> {
    if mime_types.is_empty() {
        return attachments.clone();
    }
    
    attachments
        .iter()
        .filter(|attachment| {
            match &attachment.content_type {
                Some(content_type) => mime_types.contains(content_type),
                None => false,
            }
        })
        .cloned()
        .collect()
}

fn write_to_disk(attachments: &Vec<Attachment>, directory: &str, prefix: &str) -> Result<Vec<String>, std::io::Error> {
    // Ensure destination directory exists
    fs::create_dir_all(directory)?;
    
    let mut filenames = Vec::new();
    
    for attachment in attachments {
        let filename = format!("{}{}", prefix, attachment.name);
        let filepath = Path::new(directory).join(&filename);
        
        match fs::write(&filepath, &attachment.content_bytes.0) {
            Ok(()) => {
                filenames.push(filename);
            },
            Err(err) => {
                // Clean up all previously written files
                for filename in filenames {
                    let filepath = Path::new(directory).join(&filename);
                    let _ = fs::remove_file(filepath);
                }
                return Err(err);
            }
        }
    }
    
    Ok(filenames)
}

#[rustler::nif]
fn extract_nested_attachments(raw_message: &str) -> NifResult<(Atom, Vec<Attachment>)> {
    match Message::parse(raw_message.as_bytes()) {
        Some(message) => Ok((atoms::ok(), get_attachments(&message))),
        None => Err(Error::Atom("error")),
    }
}

#[rustler::nif]
fn extract_attachments_to_disk(raw_message: &str, opts: Term) -> NifResult<(Atom, Vec<String>)> {
    // Try to decode as keyword list (list of tuples), fallback to empty list
    let opts_list = opts.decode::<Vec<(Atom, Term)>>().unwrap_or_default();
    
    let mime_types = get_mime_types_from_opts(&opts_list)?;
    let directory = get_directory_from_opts(&opts_list)?;
    let prefix = get_prefix_from_opts(&opts_list)?;
    
    match Message::parse(raw_message.as_bytes()) {
        Some(message) => {
            let attachments = get_attachments(&message);
            let filtered_attachments = filter_by_mime_type(&attachments, &mime_types);
            match write_to_disk(&filtered_attachments, &directory, &prefix) {
                Ok(filenames) => Ok((atoms::ok(), filenames)),
                Err(err) => Err(Error::Term(Box::new(format!("Failed to write to disk: {}", err))))
            }
        },
        None => Err(Error::Atom("error")),
    }
}

rustler::init!("Elixir.MailParser", [extract_nested_attachments, extract_attachments_to_disk]);
