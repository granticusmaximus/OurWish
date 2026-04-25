const { contextBridge } = require('electron');

contextBridge.exposeInMainWorld('ourWishDesktop', {
  platform: process.platform
});
