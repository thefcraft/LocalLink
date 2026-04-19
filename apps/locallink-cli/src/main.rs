use clap::{Parser, Subcommand};
use dotenvy::from_path;
use get_if_addrs::get_if_addrs;
use std::net::UdpSocket;

mod config;
mod dns;
mod registry;

#[derive(Debug)]
pub enum Error {
    DotEnv(dotenvy::Error),
    Io(std::io::Error),
    Registry(reqwest::Error),
    Config(config::ConfigError),
    InvalidIpFound(std::net::IpAddr),
    InvalidIp,
}

#[derive(Parser)]
#[command(name = "locallink")]
struct Cli {
    /// Load environment variables from .env
    #[arg(long, global = true)]
    env: bool,

    /// Path to .env file
    #[arg(long, global = true, default_value = "./.env")]
    env_path: String,

    /// Override BASE_URL
    #[arg(long, global = true)]
    base_url: Option<String>,

    /// Override API_KEY
    #[arg(long, global = true)]
    api_key: Option<String>,

    #[command(subcommand)]
    command: Commands,
}

#[derive(Subcommand)]
enum Commands {
    /// Run DNS proxy
    Dns {
        #[arg(long, default_value = "5353")]
        port: u16,

        /// Bind to all interfaces (0.0.0.0)
        #[arg(long)]
        bind_all: bool,
    },

    /// Register service
    Register {
        #[arg(long)]
        name: String,

        #[arg(long)]
        ip: Option<String>,
    },

    Agent {
        #[arg(long)]
        name: String,

        #[arg(long)]
        ip: Option<String>,

        #[arg(long, default_value = "5353")]
        port: u16,

        /// Bind to all interfaces (0.0.0.0)
        #[arg(long)]
        bind_all: bool,
    },

    /// List local IPs
    Ips,
}

fn parse_or_get_ip(ip: Option<String>, verbose: bool) -> Result<std::net::Ipv4Addr, Error> {
    let ip = match ip {
        Some(ip_str) => ip_str.parse().map_err(|_| Error::InvalidIp)?,
        None => {
            let socket = UdpSocket::bind("0.0.0.0:0").map_err(Error::Io)?;
            // NOTE: This doesn't actually send data
            socket.connect("8.8.8.8:80").map_err(Error::Io)?;
            let ip = socket.local_addr().map_err(Error::Io)?.ip();
            if verbose {
                println!("IP FOUND: {:?}", ip);
            }
            ip
        }
    };
    match ip {
        std::net::IpAddr::V4(v4) if !v4.is_loopback() => Ok(v4),
        _ => return Err(Error::InvalidIpFound(ip)),
    }
}

#[tokio::main]
async fn main() -> Result<(), Error> {
    let cli = Cli::parse();

    if let Commands::Ips = cli.command {
        let ifaces = get_if_addrs().map_err(Error::Io)?;
        for iface in ifaces {
            if let std::net::IpAddr::V4(ip) = iface.ip() {
                if ip.is_loopback() {
                    continue;
                }
                println!("{} → {}", iface.name, ip);
            }
        }
        return Ok(());
    }

    // Load .env only if flag is passed
    if cli.env {
        from_path(&cli.env_path).map_err(Error::DotEnv)?;
    }

    let config = config::Config::from_cli(&cli).map_err(Error::Config)?;

    match cli.command {
        Commands::Dns { port, bind_all } => {
            dns::run_dns(port, bind_all, &config).await?;
        }

        Commands::Register { name, ip } => {
            let ip = parse_or_get_ip(ip, true)?;
            registry::run_register(name, ip.to_string(), &config).await?;
        }

        Commands::Agent {
            name,
            ip,
            port,
            bind_all,
        } => {
            let ip: std::net::Ipv4Addr = parse_or_get_ip(ip, true)?;
            tokio::select! {
                res = dns::run_dns(port, bind_all, &config) => {
                    eprintln!("❌ DNS exited");
                    res?;
                }

                res = registry::run_register(name, ip.to_string(), &config) => {
                    eprintln!("❌ Registry exited");
                    res?;
                }
            }
            println!("Shutting down agent...");
        }

        Commands::Ips => {
            let ifaces = get_if_addrs().map_err(Error::Io)?;
            for iface in ifaces {
                if let std::net::IpAddr::V4(ip) = iface.ip() {
                    if ip.is_loopback() {
                        continue;
                    }
                    println!("{} → {}", iface.name, ip);
                }
            }
        }
    }
    Ok(())
}
