use crate::config::Config;
use crate::{Error, registry};
use tokio::net::UdpSocket;

pub async fn run_dns(port: u16, bind_all: bool, config: &Config) -> Result<(), Error> {
    let bind_addr = if bind_all {
        ("0.0.0.0", port)
    } else {
        ("127.0.0.1", port)
    };
    let socket = UdpSocket::bind(bind_addr).await.map_err(Error::Io)?;
    println!("DNS server running on port {}", port);

    let mut buf = [0u8; 512];

    loop {
        let (len, addr) = socket.recv_from(&mut buf).await.map_err(Error::Io)?;
        let query = &buf[..len];

        let domain = extract_domain(query);
        println!("Query: {}", domain);

        if domain.ends_with(".local") {
            let name = domain.trim_end_matches(".local");

            if let Some(ip) = registry::resolve(name, config)
                .await
                .map_err(Error::Registry)?
            {
                let response = build_response(query, &ip);
                socket.send_to(&response, addr).await.map_err(Error::Io)?;
            } else {
                let response = build_nxdomain(query);
                socket.send_to(&response, addr).await.map_err(Error::Io)?;
            }
        }
    }
}

fn extract_domain(data: &[u8]) -> String {
    let mut i = 12;
    let mut labels = vec![];

    while data[i] != 0 {
        let len = data[i] as usize;
        i += 1;
        labels.push(String::from_utf8_lossy(&data[i..i + len]).to_string());
        i += len;
    }

    labels.join(".")
}

fn build_nxdomain(query: &[u8]) -> Vec<u8> {
    let mut res = query.to_vec();
    res[2] = 0x81;
    res[3] = 0x83;
    res[6] = 0;
    res[7] = 0;
    res
}

fn build_response(query: &[u8], ip: &str) -> Vec<u8> {
    let mut res = query.to_vec();

    res[2] = 0x81;
    res[3] = 0x80;
    res[6] = 0;
    res[7] = 1;

    let mut answer = vec![
        0xC0, 0x0C, 0x00, 0x01, 0x00, 0x01, 0x00, 0x00, 0x00, 0x3C, 0x00, 0x04,
    ];

    answer.extend(ip.split('.').map(|x| x.parse::<u8>().unwrap()));

    res.extend(answer);
    res
}
