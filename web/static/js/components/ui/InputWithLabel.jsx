import React, { PropTypes, Component } from 'react'
import classNames from 'classnames/bind'

export class InputWithLabel extends Component {
  static propTypes = {
    children: PropTypes.node,
    id: PropTypes.string,
    value: PropTypes.oneOfType([
      PropTypes.string,
      PropTypes.number ]),
    label: PropTypes.string,
    errors: PropTypes.array
  }

  render() {
    const { children, id, value, label, errors } = this.props

    var childrenWithProps = React.Children.map(children, function(child) {
      return React.cloneElement(child, { id: id, value: value })
    })

    let errorMessage = null

    // TODO: the error message in a label looks bad. Fix this style problem,
    // and then uncomment these lines:
    //
    // if (errors) {
    //   errorMessage = errors.join(', ')
    // }

    return (
      <div>
        {childrenWithProps}
        <label htmlFor={id} className={classNames({'active': value})} data-error={errorMessage}>{label}</label>
      </div>
    )
  }
}
