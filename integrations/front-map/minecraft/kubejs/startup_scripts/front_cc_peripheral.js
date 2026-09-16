// Requires KubeJS + CC:Tweaked. Attach a lectern to an advanced computer.
ComputerCraftEvents.peripheral(event => {
  event.registerPeripheral('front_map', 'minecraft:lectern')
    .mainThreadMethod('getMapJSON', () => {
      return String(Utils.getServer().persistentData.getString('front_cc_snapshot'))
    })
})
