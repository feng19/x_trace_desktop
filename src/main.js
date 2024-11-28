let sidecarProcess;
let is_running = false;

async function runSidecar() {
  const { Command } = window.__TAURI__.shell;
  let resourceDir = await window.__TAURI__.path.resourceDir();
  const command = Command.sidecar("binaries/xtrace", [
    "--open=false",
    "--port=0",
    "--ip=127.0.0.1",
    "--output-server-info",
    "--app-data-dir=" + resourceDir,
  ]);
  command.stdout.on("data", (line) => {
    is_running = true;
    console.log(`command stdout: "${line}"`);
  });
  sidecarProcess = await command.spawn();
  console.log("pid:", sidecarProcess.pid);
}

window.addEventListener("DOMContentLoaded", () => {
  runSidecar();
  loop();
  // setTimeout(loop, 1000);
});

async function getServerPort() {
  const { readTextFile, BaseDirectory } = window.__TAURI__.fs;
  const server_info = await readTextFile(".server_info", {
    baseDir: BaseDirectory.Resource,
  });
  console.log("server_info:", server_info);
  return server_info.split(":")[1];
}

async function loop() {
  if (is_running && sidecarProcess) {
    console.log("sidecar is running");
    let port = await getServerPort();
    console.log("port:", port);
    window.location.href = "http://localhost:" + port;
    return;
  } else {
    setTimeout(loop, 100);
  }
}
