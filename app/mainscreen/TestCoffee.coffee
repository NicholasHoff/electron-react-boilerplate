import React from 'react'
import {Button, DropdownButton, MenuItem} from 'react-bootstrap'

console.log("hi from coffeescript")

export default (
  <div>
    <h1>coffeereact</h1>
    <Button bsStyle="primary" bsSize="large">button text</Button>
    <DropdownButton bsStyle={"info"} title={"thing"}>
      <MenuItem>Action</MenuItem>
      <MenuItem>Another action</MenuItem>
    </DropdownButton>

  </div>
)
