// @flow
import React, { Component } from 'react';
import { render as ReactDOMrender } from 'react-dom';
import TestCoffee from './TestCoffee.coffee';
import styles from './MainScreen.css';
import '../app.global.css';
import * as rb from 'react-bootstrap';

import $ from 'jquery';
import md5 from 'js-md5';
const path = require('path');
const fs = require('fs');

import {Compiler, BlockCompiler} from './compiler.coffee';
import {ConnectionPort} from './ConnectionPort.coffee';
import './copy_paste.coffee';
import DiskIO from './DiskIO.coffee';
import Library from './Library.coffee';
import {Link, BubbleLink, DanglingLink} from './Link.coffee';
import './mouse_overlay.coffee';
import NewPortButton from './NewPortButton.coffee';
import {Node, UserDataNode, RawInputNode, CodeNode, SmartInputNode, SetVariableNode, RefVariableNode, Bubble, ResultNode, Diagram} from './Node.coffee';
import './react_stuff.coffee';
import './Registry.coffee';
import StoredResults from './StoredResults.coffee';
import './utils.coffee';


const ReactBootstrap = rb;

Alonzo.debug_statement = function(statement) {
  fs.appendFileSync("./debug.txt", statement + "\n");
}

Alonzo.doittest = function () {
  ReactDOMrender(
    <div>
      <div className={styles.container}>
        <h2>Home</h2>
      </div>
    </div>
    ,document.getElementById('root')
  );
}

Alonzo.start_mainscreen_first_time = function() {
  Alonzo.debug_statement("---------------------------------------\nstarting");
  Alonzo.file_paths = {
    mm_blocks:   path.join('.', 'app', 'user_files', 'mm_blocks.json'),
    user_blocks: path.join('.', 'app', 'user_files', 'user_blocks.json'),
    diagrams:    path.join('.', 'app', 'user_files', 'diagrams.json')
  };


  // -------------------------------------------------
  // set up global handling for key presses
  // when using these, use event.which because jquery normalizes it across browsers
  let KEYCODE_DELETE              = 46;
  let KEYCODE_BACKSPACE           = 8;
  let KEYCODE_OPEN_BRACE_BRACKET  = 219;
  let KEYCODE_CLOSE_BRACE_BRACKET = 221;

  $("body").keyup( function(e) {
    if ((e.which === KEYCODE_DELETE) || (e.which === KEYCODE_BACKSPACE)) {
      return Alonzo.delete_command();
    } else if (e.which === KEYCODE_OPEN_BRACE_BRACKET) {
      return Alonzo.set_sugared_map();
    } else if (e.which === KEYCODE_CLOSE_BRACE_BRACKET) {
      return Alonzo.unset_sugared_map();
    }
  });
  Alonzo.debug_statement("set up body keyup function");


  Alonzo.Library.clearLibrary();
  Alonzo.Library.loadModelsFromFile(Alonzo.file_paths.mm_blocks, function () {
    Alonzo.Library.loadModelsFromFile(Alonzo.file_paths.user_blocks, function () {
      Alonzo.Library.loadDiagramsFromFile(Alonzo.file_paths.diagrams, function () {
        Alonzo.reinitialize_and_render_diagram("starting_diagramUUID");})})});

  Alonzo.debug_statement("done");
}

Alonzo.reinitialize_and_render_diagram = function(diagram_uuid) {
  Alonzo.volatile_state = JSON.parse(JSON.stringify(Alonzo.volatile_state_initialize));
  Alonzo.volatile_state.current_diagram_uuid = diagram_uuid;
  Alonzo.render();
}

Alonzo.render_all = function() {
  const select_diagram = function(e) {
    Alonzo.reinitialize_and_render_diagram(e);
  }

  const on_logout = function (e) {
    console.log("user clicked logout");
  }

  Alonzo.chrome_state.footer_height = (Alonzo.chrome_state.current_message != null) ? Alonzo.chrome_state.footer_height_if_message : 0;

  let header_style              = {};
  header_style.height           = Alonzo.chrome_state.header_height      + "px";

  let bodyrow_style             = {};
  bodyrow_style.top             = Alonzo.chrome_state.header_height      + "px";
  bodyrow_style.bottom          = Alonzo.chrome_state.footer_height      + "px";

  let libpan_holder_style       = {};
  libpan_holder_style.width     = Alonzo.chrome_state.library_pane_width + "px";
  libpan_holder_style.overflowY = "auto";

  let diagramarea_style         = {};
  diagramarea_style.left        = Alonzo.chrome_state.library_pane_width + "px";
  diagramarea_style.right       = "0px";

  let footer_style              = {};
  footer_style.height           = Alonzo.chrome_state.footer_height      + "px";
  footer_style.bottom           = "0px";
  footer_style.color            = "red";

  let diagram_menu_entries = [];
  Alonzo.Library.get_all_diagrams().map(function(diagram) {
    diagram_menu_entries.push(
      <rb.MenuItem
        eventKey = {diagram.uuid}
        onSelect = {select_diagram}
        key = {md5("diagram menu item" + diagram.uuid)}
      >
        {diagram.name}
      </rb.MenuItem>
    );
  });

  // <rb.Nav>
  //   <rb.NavDropdown eventKey={3} title="Diagrams" id="basic-nav-dropdown">
  //     {diagram_menu_entries}
  //     <rb.MenuItem divider />
  //     <rb.MenuItem eventKey={3.3}>Separated link</rb.MenuItem>
  //   </rb.NavDropdown>
  //   <rb.NavItem eventKey={2} onSelect={function(e, eventKey) {Alonzo.evaluate_command()}}>Evaluate</rb.NavItem>
  //   <rb.NavItem eventKey={4} onClick={on_logout}>Logout</rb.NavItem>
  // </rb.Nav>
  // <Alonzo.diagram_name_react_element/>


  const all =
    <div id="all-content" style={{position:"absolute", height:"100%", width:"100%"}}>
      <rb.Grid fluid={true}>
        <rb.Row>
            <rb.Navbar fluid>
              <rb.Navbar.Header>
                <rb.Navbar.Brand>
                  <a href="#">visX</a>
                </rb.Navbar.Brand>
              </rb.Navbar.Header>
              <rb.Nav>
                <rb.NavDropdown eventKey={3} title="Diagrams" id="basic-nav-dropdown">
                  {diagram_menu_entries}
                  <rb.MenuItem divider />
                  <rb.MenuItem eventKey={3.3}>Separated link</rb.MenuItem>
                </rb.NavDropdown>
                <rb.NavItem eventKey={2} onSelect={function(e, eventKey) {Alonzo.evaluate_command()}}>Evaluate</rb.NavItem>
                <rb.NavItem eventKey={4} onClick={on_logout}>Logout</rb.NavItem>
              </rb.Nav>
              <Diagram_name_react_element/>
            </rb.Navbar>
        </rb.Row>
      </rb.Grid>
      <div id="nh-bodyrow" className="nh-row" style={bodyrow_style}>
        <div id="nh-libpan-holder" className="nh-col" style={libpan_holder_style}>
          <Library_search_box/>
          {Alonzo.render_library_pane()}
        </div>
        <div id="nh-diagram-holder" className="nh-col" style={diagramarea_style}>
          {Alonzo.render_diagram()}
        </div>
      </div>
      <div id="nh-footer" className="nh-row" style={footer_style}>
        <p>{Alonzo.chrome_state.current_message}</p>
      </div>
      {/*
      */}
    </div>

  return ReactDOMrender(all, document.getElementById("root"));
}

class Diagram_name_react_element extends React.Component {
  onChange(event) {
    return this.setState({value: event.target.value});
  }

  onKeyPress(event) {
    if (event.key === "Enter") {
      return this._onNewDiagramName(this.state.value);
    }
  }

  onBlur(event) {
    return this._onNewDiagramName(this.state.value);
  }

  onFocus(event) {
    Alonzo.chrome_state.editing_diagram_name = true;
    this.setState({value: Alonzo.Library.get_current_diagram().name});
    return Alonzo.render_all();
  }

  _onNewDiagramName(new_name) {
    Alonzo.chrome_state.editing_diagram_name = false;
    Alonzo.Library.set_name_of_current_diagram(new_name);
    Alonzo.Library.flush_to_database();
    return Alonzo.render_all();
  }

  _stringToRender() {
    if (Alonzo.chrome_state.editing_diagram_name) {
      return this.state.value;
    } else {
      return Alonzo.Library.get_current_diagram().name;
    }
  }
  render() {
    return (
      <ReactBootstrap.Navbar.Form pullRight>
        <ReactBootstrap.FormGroup>
          <ReactBootstrap.FormControl
            type       = "text"
            value      = {this._stringToRender()}
            onChange   = {this.onChange}
            onKeyPress = {this.onKeyPress}
            onBlur     = {this.onBlur}
            onFocus    = {this.onFocus}
          />
        </ReactBootstrap.FormGroup>
      </ReactBootstrap.Navbar.Form>
    );
  }
}

Alonzo.debug_statement("just created diagram_name_react_element");

class Library_search_box extends React.Component {
  getInitialState() { return {}; }

  handleChange(e) {
    Alonzo.chrome_state.library_search_box_text = e.target.value;
    return Alonzo.render_all();
  }

  render() {
    let search_icon = <ReactBootstrap.Glyphicon glyph="search" />

    return (
      <form>
        <rb.FormGroup>
          <rb.InputGroup>
            <rb.FormControl
              type        = "text"
              value       = {Alonzo.chrome_state.library_search_box_text}
              placeholder = "search"
              onChange    = {this.handleChange}
            />
            <rb.InputGroup.Addon>
              <rb.Glyphicon glyph="search" />
            </rb.InputGroup.Addon>
          </rb.InputGroup>
        </rb.FormGroup>
      </form>
    );
  }
}

Alonzo.render_library_pane = function() {
  // first calculate all categories of models
  // all the models that aren't diagram models
  // also an I/O category for bubble and singleton input
  let allCategories = [];
  for (var m of Array.from(Alonzo.Library.get_all_models())) {
    if (m.diagram !== true) {
      if (!Array.from(allCategories).includes(m.category)) {
        allCategories.push(m.category);
      }
    }
  }
  allCategories.push("input / output");
  allCategories.push("storage");


  // library_pane_entries_by_category has format
  //   {
  //     "arithmetic": [
  //       {
  //         specifier:    (plus uuid)
  //         display_name: "Plus"
  //         search_match: true
  //       }
  //       ...
  //     ]
  //     "input / output" : [
  //       {
  //         specifier:    "AAAbubble"
  //         display_name: "Output"
  //         search_match: false
  //       }
  //       ...
  //     ]
  //     ...
  //   }

  let library_pane_entries_by_category = {};

  library_pane_entries_by_category["input / output"] =
    [
      // {
      //   specifier:    "AAAbubble",
      //   display_name: "output"
      // },
      {
        specifier:    "AAAresult",
        display_name: "result"
      },
      {
        specifier:    "AAAraw",
        display_name: "raw input"
      },
      {
        specifier:    "AAAsemantic",
        display_name: "input"
      },
      {
        specifier:    "AAAcodenode",
        display_name: "Wolfram Language Code"
      }
    ];
  library_pane_entries_by_category["storage"] =
    [
      {
        specifier:    "AAAsetvariable",
        display_name: "store"
      },
      {
        specifier:    "AAArefvariable",
        display_name: "load"
      }
    ];

  for (var category of Array.from(allCategories)) {
    if ((category !== "input / output") && (category !== "storage")) {
      library_pane_entries_by_category[category] = (() => {
        let result = [];
        for (m of Array.from(Alonzo.Library.get_all_models())) {
          if (m.category === category) {
            result.push({
              specifier:    m.uuid,
              display_name: m.name
            });
          }
        }
        return result;
      })();
    }
  }

  // now put in the search_match stuff
  let search_text = Alonzo.chrome_state.library_search_box_text;
  let show_this_one = display_name => (search_text === "") || (display_name.toLowerCase().indexOf(search_text.toLowerCase()) > -1);
  for (category of Array.from(allCategories)) {
    for (let entry of Array.from(library_pane_entries_by_category[category])) {
      entry.search_match = show_this_one(entry.display_name);
    }
  }

  let render_single_entry = function(entry) {
    let onMouseDown = function() {
      let onMouseMove = function() {
        Alonzo.chrome_state.mouse_drag_lib_entry = true;
        Alonzo.chrome_state.mouse_down_lib_entry = false;
      };

      let onMouseUp = function(e) {
        if (Alonzo.chrome_state.mouse_down_lib_entry) {
          //clicked on a library entry
        } else if (Alonzo.chrome_state.mouse_drag_lib_entry) {
          let position_in_svg_tag = Alonzo.abs_to_rel(e.clientX, e.clientY);
          Alonzo.make_new_node(entry.specifier, position_in_svg_tag); //this also renders
        }
        $(document).off("mousemove");
        $(document).off("mouseup");
      };

      Alonzo.chrome_state.mouse_down_lib_entry           = true;
      // these are not actually used because onMouseUp formes a closure on entry.specifier.
      Alonzo.chrome_state.drag_from_library.display_name = entry.display_name;
      Alonzo.chrome_state.drag_from_library.specifier    = entry.specifier;

      $(document).mousemove(onMouseMove);
      $(document).mouseup(onMouseUp);
    };

    return <p key={md5("library pane entry for " + entry.specifier)} onMouseDown={onMouseDown} style={{"WebkitUserSelect": "none"}}>
      {entry.display_name}
    </p>
  };

  let render_single_category = function(category) {
    let x;
    let show_this_category = Array.from((() => {
      let result1 = [];
      for (x of Array.from(library_pane_entries_by_category[category])) {         result1.push(x.search_match);
      }
      return result1;
    })()).includes(true);
    if (!show_this_category) { return null; }

    let key = md5(`library panel category header${category}`);

    //have to say "is true" because it could be null
    let expanded = (Alonzo.chrome_state.library_panels_expanded[category] === true) || (Alonzo.chrome_state.library_search_box_text !== "");

    let onSelect = function(event, eventKey) {
      console.log(eventKey);
      Alonzo.chrome_state.library_panels_expanded[event] = (!expanded);
      return Alonzo.render_all();
    };

    let header =
      (
        <span>
          <ReactBootstrap.Glyphicon
            style = {{"paddingRight":"10px"}}
            glyph = {expanded ? "menu-down" : "menu-right"}
          />
          <span key={md5("header category name" + key)} style={{"WebkitUserSelect": "none"}}>
            {category}
          </span>
        </span>
      );

    return (
      <rb.Panel
        key      = {key}
        header   = {header}
        eventKey = {category}
        collapsible
        expanded = {expanded}
        onSelect = {onSelect}
        style    = {{"margin":"0px"}}
      >
        {((() => {
          let result2 = [];
          for (x of Array.from(library_pane_entries_by_category[category])) {
            if (x.search_match) {
              result2.push(render_single_entry(x));
            }
          }
          return result2;
        })())}
      </rb.Panel>
    );

  };

  // make this a PanelGroup?
  return <div key="library pane div">
    {((() => {
      let result1 = [];
      for (let x of Array.from(allCategories)) {
        result1.push(render_single_category(x));
      }
      return result1;
    })())}
  </div>
};
