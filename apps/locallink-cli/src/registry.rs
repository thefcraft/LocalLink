use crate::config::Config;
use reqwest;
use serde::{Deserialize, Serialize};
use std::time::Duration;
use tokio::time::sleep;

#[derive(Serialize)]
struct RegisterReq {
    name: String,
    ip: String,
    ttl: u32,
}

#[derive(Deserialize)]
struct ResolveRes {
    ip: String,
}

pub async fn resolve(name: &str, config: &Config) -> Result<Option<String>, reqwest::Error> {
    let client = reqwest::Client::new();

    let res = client
        .get(format!("{}/resolve/{}", config.base_url, name))
        .header("X-API-Key", config.api_key.clone())
        .send()
        .await?;

    if res.status().is_success() {
        let data: ResolveRes = res.json().await?;
        Ok(Some(data.ip))
    } else {
        Ok(None)
    }
}

pub async fn register(name: &str, ip: &str, config: &Config) -> Result<(), reqwest::Error> {
    let client = reqwest::Client::new();

    let body = RegisterReq {
        name: name.to_string(),
        ip: ip.to_string(),
        ttl: 90,
    };

    let res = client
        .post(format!("{}/register", config.base_url))
        .header("X-API-Key", config.api_key.clone())
        .json(&body)
        .send()
        .await?;

    if res.status().is_success() {
        println!("Registered: {} → {}", name, ip);
    } else {
        println!("Register failed");
    }

    Ok(())
}

pub async fn run_register(name: String, ip: String, config: &Config) -> Result<(), crate::Error> {
    // conflict check
    if let Some(existing) = resolve(&name, config).await.map_err(crate::Error::Registry)? {
        if existing != ip {
            println!("Name already taken by {}", existing);
            return Ok(());
        }
    }

    register(&name, &ip, config).await.map_err(crate::Error::Registry)?;

    println!("Starting heartbeat...");

    loop {
        sleep(Duration::from_secs(60)).await;
        register(&name, &ip, config).await.map_err(crate::Error::Registry)?;
    }
}
