# Automated Agile Coding Standards

## Table of Contents
1. [Introduction](#1-introduction)
2. [General Principles](#2-general-principles)
3. [Language-Specific Standards (Python)](#3-language-specific-standards-python)
4. [Automated Agile Specific Standards](#4-automated-agile-specific-standards)
5. [LLM-Optimised Code Structure](#5-llm-optimised-code-structure)
6. [Extreme Modularity and Single Responsibility](#6-extreme-modularity-and-single-responsibility)
7. [Code Review Checklist](#7-code-review-checklist)
8. [Continuous Improvement](#8-continuous-improvement)

## 1. Introduction

These coding standards are specifically designed for Automated Agile development environments. They aim to create high-quality, maintainable code that is optimised for both human developers and AI-assisted development processes. In the context of Automated Agile, where AI plays a significant role in code generation, analysis, and improvement, these standards emphasise clarity, consistency, rich contextual information, and extreme modularity.

The primary goals of these standards are to:
1. Facilitate effective collaboration between human developers and AI systems
2. Enhance the AI's ability to understand, generate, and modify code
3. Streamline the automated processes in agile development
4. Maintain code quality and readability for human developers

By adhering to these standards, teams can maximize the benefits of AI-assisted development while ensuring that the codebase remains manageable and understandable for human developers.

## 2. General Principles

### 2.1 Clarity and Readability
- Write code that is easy to read and understand for both humans and AI.
- Prioritise clarity over cleverness or brevity.
- Use meaningful and descriptive names for variables, functions, and classes.

### 2.2 Consistency
- Maintain consistent coding style throughout the project.
- Follow established patterns and conventions within the codebase.

### 2.3 Modularity
- Write highly modular code with clear separation of concerns.
- Aim for high cohesion within modules and loose coupling between modules.
- Break down complex operations into smaller, single-responsibility functions.

### 2.4 Documentation
- Include clear, concise comments for complex logic or non-obvious code.
- Provide meaningful docstrings for all classes and functions.
- Ensure documentation is AI-readable and context-rich.

### 2.5 Error Handling
- Implement robust error handling and logging.
- Use exceptions appropriately and catch them at the right level.
- Include contextual information in error messages and logs.

### 2.6 Testing
- Write unit tests for all new code.
- Maintain high test coverage, aiming for at least 80%.
- Include context and purpose in test case descriptions.

### 2.7 Version Control
- Make small, focused commits with clear commit messages.
- Use feature branches and pull requests for new features or significant changes.
- Tag versions corresponding to specific AI training or analysis points.

## 3. Language-Specific Standards (Python)

### 3.1 Code Formatting
- Follow PEP 8 guidelines for code formatting.
- Use tools like Black for automatic code formatting.
- Limit line length to 88 characters (Black's default).

### 3.2 Naming Conventions
- Use snake_case for function and variable names.
- Use PascalCase for class names.
- Use UPPERCASE for constants.
- Prefix private attributes with a single underscore.

### 3.3 Imports
- Group imports in the following order: standard library, third-party libraries, local modules.
- Use absolute imports when possible.
- Avoid wildcard imports (`from module import *`).

### 3.4 Function and Method Design
- Keep functions and methods extremely short and focused on a single, atomic task.
- Aim for a maximum of 20-30 lines per function, with rare exceptions for unavoidably complex logic.
- Use type hints for function parameters and return values.
- Prefer multiple simple functions over a single complex function.
- Ensure each function has a clear, single responsibility.

### 3.5 Class Design
- Follow the Single Responsibility Principle strictly.
- Break down large classes into smaller, more focused classes.
- Use composition over inheritance to build complex behaviours.
- Keep method implementations short, delegating to other methods or functions as needed.
- Use properties instead of getter and setter methods when appropriate.
- Implement `__str__` and `__repr__` methods for meaningful string representations.

### 3.6 Error Handling
- Use context managers (`with` statements) for resource management.
- Raise exceptions with meaningful error messages.
- Use custom exceptions when appropriate.
- Include file and function identifiers in exception messages.

### 3.7 Asynchronous Code
- Use `async`/`await` syntax for asynchronous operations.
- Clearly distinguish between synchronous and asynchronous functions.
- Keep asynchronous functions small and focused.

## 4. Automated Agile Specific Standards

### 4.1 AI-Readability
- Structure code to be easily parseable by AI tools.
- Use clear, descriptive variable names that convey purpose and content.
- Include inline comments explaining complex logic or business rules.

### 4.2 Modular Documentation
- Maintain up-to-date module-level documentation.
- Use standardised docstring formats (e.g., Google style) for consistent AI parsing.
- Include context and relationships to other modules in documentation.

### 4.3 Version Tagging
- Tag code versions that correspond to specific AI training or analysis points.
- Include version information in module docstrings.

### 4.4 Metadata Annotations
- Use decorators or comments to provide metadata about functions and classes.
- Include information like complexity, dependencies, and last review date.

### 4.5 Test Case Clarity
- Write test case names and docstrings that clearly describe the scenario being tested.
- Include expected inputs and outputs in test case documentation.

### 4.6 Refactoring Hints
- Use TODO comments to mark areas for potential refactoring or optimisation.
- Include brief explanations of why refactoring might be needed.

### 4.7 Performance Considerations
- Add comments about performance characteristics for complex operations.
- Use decorators to mark performance-critical functions.

### 4.8 Dependency Management
- Clearly document external dependencies and version requirements.
- Use tools like Poetry or Pipenv for reproducible environments.

### 4.9 Configuration Management
- Use environment variables or configuration files for environment-specific settings.
- Document the purpose and possible values for each configuration option.

### 4.10 Logging Standards
- Implement consistent, structured logging across the application.
- Include contextual information in log messages to aid in automated analysis.

## 5. LLM-Optimised Code Structure

### 5.1 File Header
Each code file must begin with a comprehensive header containing:

- File description: A detailed explanation of the file's purpose and functionality.
- Unique identifier: A machine-readable naming convention for easy reference.
- Version information: Current version number and last update date.
- Author(s): Names or identifiers of the original author(s) and last modifier.
- Dependencies: List of other files or modules necessary to understand or run this code.
- Product context: Brief description of how this file fits into the larger product or feature set.

Example:
```python
"""
File: user_authentication.py
Unique ID: AUTH001
Version: 1.2.3 (Last updated: 2024-10-11)
Author(s): J. Doe, A. Smith
Dependencies: 
  - AUTH002: session_management.py
  - AUTH003: password_hashing.py
  - DB001: database_connector.py

Description:
This file handles user authentication processes for the MyApp platform. 
It includes functions for user login, logout, and session management.

Product Context:
Part of the User Management module in MyApp, this file is crucial for 
maintaining secure user access across all platform features.
"""
```

### 5.2 Function and Class Documentation
Enhance existing docstring standards to include:

- Relationship to other components
- Expected input/output data structures
- Error scenarios and how they're handled
- Performance considerations

Example:
```python
def authenticate_user(username: str, password: str) -> bool:
    """
    Authenticates a user against the database.

    Related Components:
    - Uses password_hashing.py (AUTH003) for secure password comparison
    - Updates session in session_management.py (AUTH002) on success

    Args:
        username (str): The user's username
        password (str): The user's password

    Returns:
        bool: True if authentication successful, False otherwise

    Raises:
        DatabaseConnectionError: If unable to connect to the user database
        
    Error Handling:
    - Invalid credentials result in a False return, not an exception
    - Database errors are logged and re-raised

    Performance Note:
    This function includes a database call and should not be called in tight loops.
    """
    # Function implementation
```

### 5.3 Error Handling and Logging
Standardise error messages and logging to always include:

- Unique file identifier
- Function or method name
- Specific error type
- Contextual information

Example:
```python
try:
    # Some operation
except SomeError as e:
    logger.error(f"AUTH001:authenticate_user - DatabaseConnectionError: {str(e)}")
    raise DatabaseConnectionError(f"AUTH001: Failed to connect to user database: {str(e)}")
```

### 5.4 Code Comments
Enhance inline comments to provide context for complex logic:

- Explain "why" rather than just "what"
- Reference business rules or requirements where applicable
- Mention any performance or security considerations

Example:
```python
# AUTH001: We use bcrypt for password hashing due to its resistance to 
# rainbow table attacks and configurable work factor (see SEC-REQ-201)
hashed_password = bcrypt.hashpw(password.encode('utf-8'), bcrypt.gensalt())
```

### 5.5 Dependency Mapping
Include a section in each file that maps out its relationships:

```python
"""
Dependency Map:
- Calls: 
  - AUTH003:hash_password
  - DB001:execute_query
- Called by:
  - UI002:login_view
  - API001:authenticate_endpoint
- Shares data with:
  - AUTH002:create_session (user_id)
"""
```

### 5.6 Feature Flags and Configuration
Document any feature flags or configuration options that affect the file's behaviour:

```python
"""
Feature Flags:
- ENABLE_2FA: Enables two-factor authentication (default: False)
- MAX_LOGIN_ATTEMPTS: Maximum failed login attempts before account lock (default: 5)

Configuration:
- SESSION_TIMEOUT: Time in minutes before a session expires (default: 30)
"""
```

## 6. Extreme Modularity and Single Responsibility

### 6.1 Function Atomicity
- Break down complex operations into multiple, simple functions.
- Each function should perform one clearly defined task.
- Aim for functions that are no more than 20-30 lines long.

### 6.2 Class Granularity
- Create small, focused classes rather than large, multi-purpose ones.
- Each class should have a single, well-defined responsibility.
- Use composition to build complex behaviours from simple components.

### 6.3 Module Organization
- Organize related functions and classes into coherent modules.
- Keep module sizes manageable, splitting into sub-modules if necessary.
- Ensure each module has a clear, singular purpose.

### 6.4 Interface Design
- Design clean, minimal interfaces between components.
- Use dependency injection to manage component relationships.
- Favor stateless designs where possible to simplify testing and reuse.

## 7. Code Review Checklist

- [ ] Code adheres to formatting standards
- [ ] Naming conventions are followed consistently
- [ ] Functions and classes have clear, single responsibilities
- [ ] Error handling is robust and appropriate
- [ ] Unit tests are included and cover critical paths
- [ ] Documentation is clear, concise, and up-to-date
- [ ] No unnecessary complexity or premature optimization
- [ ] Performance considerations are addressed for critical sections
- [ ] Security best practices are followed
- [ ] Code is easily parseable by AI tools
- [ ] File headers and dependency mappings are complete and accurate
- [ ] Extreme modularity principles are applied appropriately

## 8. Continuous Improvement

- Regularly review and update these standards based on team feedback and project needs.
- Automate as much of the standards enforcement as possible through linting and CI/CD pipelines.
- Conduct periodic code quality reviews using both human and AI-assisted techniques.
- Continuously refine AI prompts and training data to improve AI-assisted development processes.
- Encourage team members to suggest improvements to the standards and Automated Agile processes.

By following these Automated Agile Coding Standards, teams can create code that is not only high-quality and maintainable by human developers but also optimized for AI analysis, generation, and assistance. This approach facilitates a smooth integration of AI tools into the agile development process, leading to increased productivity and code quality.
