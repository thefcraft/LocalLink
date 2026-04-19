use std::env;

#[derive(Debug)]
pub struct Config {
    pub base_url: String,
    pub api_key: String,
}

#[derive(Debug)]
pub enum ConfigError {
    MissingBaseUrl,
    MissingApiKey,
}

impl Config {
    pub fn from_cli(cli: &crate::Cli) -> Result<Self, ConfigError> {
        let base_url = match &cli.base_url {
            Some(base_url) => base_url.clone(),
            None => match env::var("BASE_URL") {
                Ok(base_url) => base_url,
                Err(_) => return Err(ConfigError::MissingBaseUrl),
            },
        };
        let api_key = match &cli.api_key {
            Some(api_key) => api_key.clone(),
            None => match env::var("API_KEY") {
                Ok(api_key) => api_key,
                Err(_) => return Err(ConfigError::MissingApiKey),
            },
        };
        Ok(Self { base_url, api_key })
    }
}
